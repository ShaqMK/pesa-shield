"""Pesa Shield - Server-side data layer.

The ingestion webhook, the feed and the admin walkers. Nodes live on the
shared guest root: an anonymous `:pub` caller runs on the one shared graph,
the model the T1 tracer settled for Jac Hammer (forwarder posts anonymous,
web feed reads anonymous, everyone sees one feed). Credentials are checked
in the request body per tier (webhook secret, admin secret).

Names follow GLOSSARY.md. Redaction follows the contract in redaction.jac:
only HMAC keys, masked display strings and neutral-token text are stored.
"""

import os;
import hmac;
import from datetime {
    datetime
}
import from taxonomy {
    PATTERN_TAXONOMY
}
import from redaction {
    identify_sender,
    redact
}

node Sender {
    has key: str,  # HMAC sender key, never the raw identifier
        display: str;  # masked display string
}

node Message {
    has display: str,  # masked text for UI
        llm_text: str,  # neutral-token text, the only text Guard's LLM sees
        fingerprint: str,  # dedupe identity of the redacted text
        entities: list[dict[str, str]],  # kind, key, display, token
        sender_key: str,
        sender_display: str,
        status: str,  # analysing -> eventually a verdict lands here
        created_at: str;
}

node Pattern {
    has name: str,  # taxonomy label, e.g. fee_before_loan
        title: str,
        description: str;
}

glob MAX_TEXT_LEN: int = 2000;
glob DEDUPE_WINDOW_SEC: float = 600.0;
glob RATE_WINDOW_SEC: float = 60.0;
# Per-window call timestamps by bucket. In-process: one Hammer instance.
glob _rate_hits: dict[str, list[float]] = {};


def _now -> float {
    return datetime.now().timestamp();
}


"""Reject unless `given` matches the secret configured in env var `env_name`.

One helper for every credential tier (webhook, admin). Raised exceptions
surface as ok=false rejections on the wire.
"""
def _require_secret(env_name: str, given: str) {
    expected = os.getenv(env_name, "");
    if not expected {
        raise RuntimeError(f"not_configured: {env_name} is not set on the server");
    }
    if not hmac.compare_digest(given.encode(), expected.encode()) {
        raise RuntimeError("forbidden: wrong or missing secret");
    }
}


"""Reject once `bucket` has had `limit` calls within the rate window."""
def _require_rate(bucket: str, limit: int) {
    t = _now();
    hits = [h for h in _rate_hits.get(bucket, []) if t - h < RATE_WINDOW_SEC];
    if len(hits) >= limit {
        _rate_hits[bucket] = hits;
        raise RuntimeError("rate_limited: too many requests, slow down");
    }
    hits.append(t);
    _rate_hits[bucket] = hits;
}


def _pattern_count -> int {
    return len([root -->[?:Pattern]]);
}


"""Create any missing taxonomy Patterns and refresh existing ones. Idempotent.

Returns how many Patterns were created.
"""
def seed_patterns -> int {
    existing = {p.name: p for p in [root -->[?:Pattern]]};
    created = 0;
    for spec in PATTERN_TAXONOMY {
        pattern = existing.get(spec["name"]);
        if pattern is None {
            root ++> Pattern(
                name=spec["name"],
                title=spec["title"],
                description=spec["description"]
            );
            created += 1;
        } else {
            pattern.title = spec["title"];
            pattern.description = spec["description"];
        }
    }
    return created;
}


"""Public webhook the forwarder posts to.

Body fields: secret, sender, text. Returns { id, status: analysing }
immediately; Guard analysis is a later slice. A duplicate (same sender key,
identical redacted text within the window) returns the existing id with
dedupe=true. Wrong or missing secret, invalid input and rate-limit overflow
reject with ok=false.
"""
walker:pub IngestMessage {
    has secret: str = "",
        sender: str = "",
        text: str = "",
        reports: list[dict[str, str]] = [];

    can ingest with Root entry {
        _require_secret("PESA_WEBHOOK_SECRET", self.secret);
        if not self.text.strip() or not self.sender.strip() {
            raise ValueError("invalid: sender and text are required");
        }
        if len(self.text) > MAX_TEXT_LEN {
            raise ValueError(f"invalid: text longer than {MAX_TEXT_LEN} characters");
        }
        identity = identify_sender(self.sender);
        redacted = redact(self.text);
        existing = [root -->[?:Sender, key == identity.key]];

        # Dedupe before the rate limit so forwarder retries are never rejected.
        cutoff = _now() - DEDUPE_WINDOW_SEC;
        prior = [existing[0] -->[?:Message]] if existing else [];
        for m in prior {
            if m.fingerprint == redacted.fingerprint and float(m.created_at) > cutoff {
                report {"id": jid(m), "status": m.status, "dedupe": "true"};
                disengage;
            }
        }

        _require_rate("ingest", int(os.getenv("PESA_INGEST_RATE_MAX", "30")));
        # Auto-seed so a redeploy that lost the graph can't leave it unseeded.
        if _pattern_count() < len(PATTERN_TAXONOMY) {
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
            status="analysing",
            created_at=str(_now())
        ))[0];
        report {"id": jid(msg), "status": "analysing"};
    }
}


"""Read-only feed: recent messages, newest first."""
walker:pub WebFeed {
    has limit: int = 50,
        reports: list[dict[str, str]] = [];

    can collect with Root entry {
        # Messages live under Sender nodes, which live on the root.
        msgs = [root -->[?:Sender]-->[?:Message]];
        msgs = sorted(msgs, key=lambda m: Message : float(m.created_at), reverse=True);
        for m in msgs[:self.limit] {
            report {
                "id": jid(m),
                "display": m.display,
                "sender_display": m.sender_display,
                "status": m.status,
                "created_at": m.created_at
            };
        }
    }
}


"""Admin: seed the taxonomy Patterns. Idempotent; requires the admin secret."""
walker:pub Seed {
    has secret: str = "",
        reports: list[dict[str, int]] = [];

    can run with Root entry {
        _require_secret("PESA_ADMIN_SECRET", self.secret);
        created = seed_patterns();
        report {"created": created, "patterns": _pattern_count()};
    }
}


"""Admin: wipe ingested data (Senders, Messages) and rate-limit state, then
re-seed the Patterns. Idempotent; requires the admin secret.
"""
walker:pub Reset {
    has secret: str = "",
        reports: list[dict[str, int]] = [];

    can run with Root entry {
        _require_secret("PESA_ADMIN_SECRET", self.secret);
        removed = 0;
        for s in [root -->[?:Sender]] {
            for m in [s -->[?:Message]] {
                del m;
                removed += 1;
            }
            del s;
        }
        _rate_hits.clear();
        seed_patterns();
        report {"removed_messages": removed, "patterns": _pattern_count()};
    }
}
