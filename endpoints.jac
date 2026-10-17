"""Pesa Shield - Server-side ingestion, feed and admin walkers.

Nodes live on the shared guest root: an anonymous `:pub` caller runs on the
one shared graph, the model the T1 tracer settled for Jac Hammer (forwarder
posts anonymous, web feed reads anonymous, everyone sees one feed).
Credentials are checked in the request body per tier (see access.jac).

Names follow GLOSSARY.md. Redaction follows the contract in redaction.jac:
only HMAC keys, masked display strings and neutral-token text are stored.
"""

import os;
import json;
import from time {
    sleep
}
import from urllib.request {
    Request,
    urlopen
}
import from access {
    now,
    rate_hits,
    require_rate,
    require_secret,
    require_text
}
import from model {
    Case,
    Message,
    PayTarget,
    Sender,
    all_messages,
    message_view,
    pattern_count,
    seed_patterns
}
import from taxonomy {
    PATTERN_TAXONOMY
}
import from redaction {
    identify_sender,
    redact,
    template_hash
}
import from labelled {
    labelled_key
}

glob DEDUPE_WINDOW_SEC: float = 600.0;


"""Where this server reaches itself to run Guard after the ingest response.

PESA_SELF_URL overrides; "off" disables (tests). Default: this host on the
served port - JAC_SERVE_PORT, else PORT, else 8000 (the jac 0.37 default).
"""
def _self_url -> str {
    port = os.getenv("JAC_SERVE_PORT") or os.getenv("PORT") or "8000";
    return os.getenv("PESA_SELF_URL", f"http://localhost:{port}");
}


"""Run Guard for a message in its own request (async ingestion).

Called via `flow` after IngestMessage has its response ready, so it only
does HTTP - no graph access off the request context. Retries briefly in
case the ingest write has not committed yet. Failures leave the message
`analysing` for GuardPending to pick up.
"""
def kick_guard(message_id: str) {
    base = _self_url();
    if base == "off" {
        return;
    }
    body = json.dumps(
        {"secret": os.getenv("PESA_WEBHOOK_SECRET", ""), "message_id": message_id}
    ).encode();
    for attempt in range(3) {
        sleep(0.2 + attempt);
        try {
            # A rejected call raises (HTTP 500 on jac 0.37); it is logged below.
            req = Request(
                base.rstrip("/") + "/walker/GuardMessage",
                data=body,
                headers={"Content-Type": "application/json"}
            );
            reply = (urlopen(req, timeout=120).read() as bytes).decode();
            if "not_found" not in reply {
                return;
            }
        } except Exception as e {
            print(f"kick_guard: {type(e).__name__}");
        }
    }
}


"""Public webhook the forwarder posts to.

Body fields: secret, sender, text. Returns { id, status: analysing }
immediately and runs Guard after the response (kick_guard). A duplicate
(same sender key, identical redacted text within the window) returns the
existing id with dedupe=true and is not re-analysed. Wrong or missing
secret, invalid input and rate-limit overflow are rejected: nothing is
stored and `data.error` carries the reason.
"""
walker:pub IngestMessage {
    has secret: str = "",
        sender: str = "",
        text: str = "",
        reports: list[dict[str, str]] = [];

    can ingest with Root entry {
        (given, self.secret) = (self.secret, "");  # never echoed back
        require_secret("PESA_WEBHOOK_SECRET", given);
        # Raw identifiers stay in locals; the walker (echoed as `result`) keeps none.
        (raw_text, raw_sender, self.text, self.sender) = (self.text, self.sender, "", "");
        require_text(raw_text);
        if not raw_sender.strip() {
            raise ValueError("invalid: sender is required");
        }
        identity = identify_sender(raw_sender);
        redacted = redact(raw_text);
        existing = [root -->[?:Sender, key == identity.key]];

        # Dedupe before the rate limit so forwarder retries are never rejected.
        cutoff = now() - DEDUPE_WINDOW_SEC;
        prior = [existing[0] -->[?:Message]] if existing else [];
        for m in prior {
            if m.fingerprint == redacted.fingerprint and float(m.created_at) > cutoff {
                report {"id": jid(m), "status": m.status, "dedupe": "true"};
                disengage;
            }
        }

        require_rate("ingest", "PESA_INGEST_RATE_MAX", 30);
        # Auto-seed so a redeploy that lost the graph can't leave it unseeded.
        if pattern_count() < len(PATTERN_TAXONOMY) {
            seed_patterns();
        }

        sender = existing[0] if existing else Sender(key=identity.key, display=identity.display);
        if not existing {
            root ++> sender;
        }

        msg = Message(
            display=redacted.display,
            llm_text=redacted.llm_text,
            fingerprint=redacted.fingerprint,
            entities=redacted.entities,
            sender_key=identity.key,
            sender_display=identity.display,
            sender_kind=identity.kind,
            status="analysing",
            created_at=str(now()),
            template_hash=template_hash(redacted.llm_text),
            cache_key=labelled_key(raw_text)
        );
        sender ++> msg;
        message_id = jid(msg);
        flow kick_guard(message_id);
        report {"id": message_id, "status": "analysing"};
    }
}


"""Read-only feed: recent messages with their Verdicts, newest first."""
walker:pub WebFeed {
    has limit: int = 50,
        reports: list[dict[str, any]] = [];

    can collect with Root entry {
        msgs = sorted(
            all_messages(), key=lambda (m: Message) -> float { float(m.created_at); }, reverse=True
        );
        for m in msgs[:self.limit] {
            report message_view(m);
        }
    }
}


"""Read-only: one message and its Verdict, for the message detail screen."""
walker:pub GetMessage {
    has message_id: str = "",
        reports: list[dict[str, any]] = [];

    can fetch with Root entry {
        target: any = None;
        try {
            target = jobj(self.message_id);
        } except Exception {
            target = None;
        }
        if not isinstance(target, Message) {
            report {"status": "not_found"};
            disengage;
        }
        report message_view(target);
    }
}


"""Admin: seed the taxonomy Patterns. Idempotent; requires the admin secret."""
walker:pub Seed {
    has secret: str = "",
        reports: list[dict[str, int]] = [];

    can run with Root entry {
        (given, self.secret) = (self.secret, "");  # never echoed back
        require_secret("PESA_ADMIN_SECRET", given);
        created = seed_patterns();
        report {"created": created, "patterns": pattern_count()};
    }
}


"""Admin: wipe ingested data (Senders, Messages, PayTargets, Cases) and rate-limit
state, then re-seed the Patterns. Idempotent; requires the admin secret.
"""
walker:pub Reset {
    has secret: str = "",
        reports: list[dict[str, int]] = [];

    can run with Root entry {
        (given, self.secret) = (self.secret, "");  # never echoed back
        require_secret("PESA_ADMIN_SECRET", given);
        removed = 0;
        for s in [root -->[?:Sender]] {
            for m in [s -->[?:Message]] {
                del m;
                removed += 1;
            }
            del s;
        }
        for t in [root -->[?:PayTarget]] {
            del t;
        }
        for c in [root -->[?:Case]] {
            del c;
        }
        rate_hits.clear();
        seed_patterns();
        report {"removed_messages": removed, "patterns": pattern_count()};
    }
}
