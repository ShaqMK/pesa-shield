"""Pesa Shield - Server-side data layer (T1 tracer).

The ingestion webhook and the feed. Nodes live on the shared guest root:
an anonymous `:pub` caller runs on the one shared graph, which is the model
this tracer settles empirically for Jac Hammer (forwarder posts anonymous,
web feed reads anonymous, everyone sees one feed).

Names follow GLOSSARY.md. Redaction: mask display strings only in this slice;
raw sender strings are never stored.
"""

import os;
import from datetime {
    datetime
}

node Sender {
    has display: str;  # masked display string, never the raw identifier
}

node Message {
    has display: str,  # redacted display text
        sender_display: str,
        status: str,  # analysing -> eventually a verdict lands here
        created_at: str;
}

# Test hook: tests set this to bypass the process environment.
glob _secret_override: str = "";

# Simple per-window rate limiter for the public intake point.
glob RATE_WINDOW_MAX: int = 30;
glob RATE_WINDOW_SEC: float = 60.0;
glob _rate_hits: dict[float, str] = {};


def _now() -> float {
    return datetime.now().timestamp();
}


def _rate_ok(client_id: str) -> bool {
    t: float = _now();
    fresh = [(ts, cid) for (ts, cid) in
             [(t - k, c) for (k, c) in _rate_hits.items()]
             if t - ts < RATE_WINDOW_SEC and cid == client_id];
    if len(fresh) >= RATE_WINDOW_MAX {
        return False;
    }
    _rate_hits[t] = client_id;
    # opportunistic cleanup
    stale = [k for k in _rate_hits if t - k >= RATE_WINDOW_SEC];
    for k in stale {
        del _rate_hits[k];
    }
    return True;
}


"""Mask a raw phone number or name to a display string (last 3 digits)."""
def mask_sender(raw: str) -> str {
    only_digits = "".join(c for c in raw if c.isdigit());
    if len(only_digits) >= 4 {
        return "…" + only_digits[-3:];
    }
    return raw[:1] + "***";
}


"""Redact phone-number-like digits out of the display text."""
def mask_text(raw: str) -> str {
    out = list(raw);
    runs = [i for i in range(len(raw)) if raw[i].isdigit()];
    if len(runs) < 4 {
        return raw;
    }
    # mask all but the last 3 digits in the whole message
    keep = set(runs[-3:]);
    for i in runs {
        if i not in keep {
            out[i] = "*";
        }
    }
    return "".join(out);
}


"""Public webhook the forwarder posts to.

Body fields: secret, sender, text, client (optional id for rate limit).
Returns { id, status: analysing } immediately; Guard analysis is a later
slice. Wrong or missing secret rejects with ok=false (403).
"""
walker:pub IngestMessage {
    has secret: str = "",
        sender: str = "",
        text: str = "",
        client: str = "anon",
        reports: list[dict[str, str]] = [];

    can ingest with Root entry {
        # Raised exceptions surface as ok=false rejections on the wire.
        expected = _secret_override if _secret_override else os.getenv("PESA_WEBHOOK_SECRET", "");
        if not expected {
            raise RuntimeError("webhook_not_configured: PESA_WEBHOOK_SECRET is not set on the server");
        }
        if self.secret != expected {
            raise RuntimeError("forbidden: wrong or missing webhook secret");
        }
        if not self.text.strip() {
            raise ValueError("invalid: text is required");
        }
        cid = self.client + "|" + self.sender;
        if not _rate_ok(cid) {
            raise RuntimeError("rate_limited: too many messages, slow down");
        }

        sdis = mask_sender(self.sender);
        mdis = mask_text(self.text);

        # Get this sender's messages (Messages hang off the Sender node).
        senders = [root -->][?:Sender];
        smsgs = [m for s in senders for m in [s -->][?:Message]];

        # Dedupe on (sender display, byte-identical text) within the window.
        cutoff = _now() - 600.0;
        for m in smsgs {
            if (
                m.sender_display == sdis
                and m.display == mdis
                and float(m.created_at) > cutoff
            ) {
                report {"id": jid(m), "status": m.status, "dedupe": "true"};
                disengage;
            }
        }

        existing: Sender | None = None;
        for s in [root -->][?:Sender] {
            if s.display == sdis {
                existing = s;
                break;
            }
        }
        if existing is None {
            existing = root ++> Sender(display=sdis);
        }
        msg = existing ++> Message(
            display=mdis,
            sender_display=sdis,
            status="analysing",
            created_at=str(_now())
        );
        report {"id": jid(msg), "status": "analysing"};
    }
}


"""Read-only feed: recent messages, newest first."""
walker:pub WebFeed {
    has limit: int = 50,
        reports: list[dict[str, str]] = [];

    can collect with Root entry {
        # Messages live under Sender nodes, which live on the root.
        senders = [root -->][?:Sender];
        msgs = [m for s in senders for m in [s -->][?:Message]];
        msgs = sorted(msgs, key=lambda (m: Message) -> float { float(m.created_at) });
        msgs = msgs[::-1][:self.limit];
        for m in msgs {
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
