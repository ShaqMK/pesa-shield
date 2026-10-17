"""Credential tiers and rate limits shared by every walker.

Tiers (SPEC: Auth model): webhook secret (forwarder ingestion, Guard kicks),
admin secret (seed/reset/admin walkers), client token (Check and other
client-initiated actions). A raised exception aborts the walker's graph
mutations; on the wire (jac 0.16.7) the response is still HTTP 200 /
ok=true, with the reason in `data.error`.
"""

import os;
import hmac;
import from datetime {
    datetime
}

glob RATE_WINDOW_SEC: float = 60.0;
# Per-window call timestamps by bucket. In-process: one Hammer instance.
glob rate_hits: dict[str, list[float]] = {};


def now -> float {
    return datetime.now().timestamp();
}


"""Reject unless `given` matches the secret configured in env var `env_name`."""
def require_secret(env_name: str, given: str) {
    expected = os.getenv(env_name, "");
    if not expected {
        raise RuntimeError(f"not_configured: {env_name} is not set on the server");
    }
    if not hmac.compare_digest(given.encode(), expected.encode()) {
        raise RuntimeError("forbidden: wrong or missing secret");
    }
}


"""Reject once `bucket` has had as many calls within the rate window as env
var `limit_env` allows (else `fallback`)."""
def require_rate(bucket: str, limit_env: str, fallback: int) {
    limit = int(os.getenv(limit_env, str(fallback)));
    t = now();
    hits = [h for h in rate_hits.get(bucket, []) if t - h < RATE_WINDOW_SEC];
    if len(hits) >= limit {
        rate_hits[bucket] = hits;
        raise RuntimeError("rate_limited: too many requests, slow down");
    }
    hits.append(t);
    rate_hits[bucket] = hits;
}


glob MAX_TEXT_LEN: int = 2000;


"""Reject empty or oversized message text."""
def require_text(text: str) {
    if not text.strip() {
        raise ValueError("invalid: text is required");
    }
    if len(text) > MAX_TEXT_LEN {
        raise ValueError(f"invalid: text longer than {MAX_TEXT_LEN} characters");
    }
}
