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
import from graph {
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

PESA_SELF_URL overrides; "off" disables (tests). Default: this host on $PORT
(else 3000, the jac.toml port).
"""
def _self_url -> str {
    return os.getenv("PESA_SELF_URL", f"http://127.0.0.1:{os.getenv('PORT', '3000')}");
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
        require_secret("PESA_WEBHOOK_SECRET", self.secret);
        require_text(self.text);
        if not self.sender.strip() {
            raise ValueError("invalid: sender is required");
        }
        identity = identify_sender(self.sender);
        redacted = redact(self.text);
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

        sender = existing[0] if existing else (
            root ++> Sender(key=identity.key, display=identity.display)
        )[0];

        msg = (sender ++> Message(
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
            cache_key=labelled_key(self.text)
        ))[0];
        flow kick_guard(jid(msg));
        report {"id": jid(msg), "status": "analysing"};
    }
}


"""Read-only feed: recent messages with their Verdicts, newest first."""
walker:pub WebFeed {
    has limit: int = 50,
        reports: list[dict[str, any]] = [];

    can collect with Root entry {
        msgs = sorted(
            all_messages(), key=lambda m: Message : float(m.created_at), reverse=True
        );
        for m in msgs[:self.limit] {
            report message_view(m);
        }
    }
}


"""Admin: seed the taxonomy Patterns. Idempotent; requires the admin secret."""
walker:pub Seed {
    has secret: str = "",
        reports: list[dict[str, int]] = [];

    can run with Root entry {
        require_secret("PESA_ADMIN_SECRET", self.secret);
        created = seed_patterns();
        report {"created": created, "patterns": pattern_count()};
    }
}


"""Admin: wipe ingested data (Senders, Messages, PayTargets) and rate-limit
state, then re-seed the Patterns. Idempotent; requires the admin secret.
"""
walker:pub Reset {
    has secret: str = "",
        reports: list[dict[str, int]] = [];

    can run with Root entry {
        require_secret("PESA_ADMIN_SECRET", self.secret);
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
        rate_hits.clear();
        seed_patterns();
        report {"removed_messages": removed, "patterns": pattern_count()};
    }
}
