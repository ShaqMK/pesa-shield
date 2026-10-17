"""Redaction contract (see GLOSSARY.md: Redaction, Sender key).

Every identifier found in a message becomes three things:
- an HMAC key over its canonical raw form (server-side secret, deterministic
  across messages) - the graph/dedupe identity;
- a masked display string (last 3 characters) for UI and storage;
- a neutral token like [PHONE_1] - all the LLM ever sees.

Raw identifiers never leave this module: callers get only `Redacted`.
"""

import os;
import re;
import hmac;
import hashlib;

# Kinds in priority order: an earlier kind claims overlapping text first.
glob _LINK_RE = re.compile(
    r"(?i)(?:https?://|www\.)\S+|\b[a-z0-9-]+(?:\.[a-z0-9-]+)*\.(?:com|co\.ke|ke|ly|me|net|org|info|xyz|link|site|online|top|click|io|app|biz|shop|live|club|co|tk)\b(?:/\S*)?"
);
# Till/paybill/account: the keyword stays readable, only group 1 is redacted.
glob _TILL_RE = re.compile(
    r"(?i)\b(?:till|pay\s*bill|business|biz|lipa(?:\s+na)?)\s*(?:no\.?|number|#)?\s*[:\-]?\s*(\d{4,8})(?!\d)"
);
glob _ACCOUNT_RE = re.compile(
    r"(?i)\b(?:account|acc|a/c)\s*(?:no\.?|number|#)?\s*[:\-]?\s*([A-Za-z]*\d[A-Za-z0-9]{3,14})\b"
);
# A person's name in M-Pesa style text: 2-4 ALL-CAPS words right before a
# phone number (group 1), or 2-4 capitalised words after "sent to",
# "received from" or "paid to" (group 2).
glob _NAME_RE = re.compile(
    r"\b((?:[A-Z][A-Z'\-]+\s+){1,3}[A-Z][A-Z'\-]+)(?=\s+(?:\+?254|0)[17]\d{2})|\b(?:sent to|received from|paid to)\s+((?:[A-Z][A-Za-z'\-]+\s+){1,3}[A-Z][A-Za-z'\-]+)\b"
);
glob _PHONE_RE = re.compile(
    r"(?<!\d)(?:\+?254[\s-]?|0)[17]\d{2}[\s-]?\d{3}[\s-]?\d{3}(?!\d)"
);
# Any other long digit run (ID numbers, card numbers...) - amounts excluded below.
glob _NUMBER_RE = re.compile(r"(?<![\d,.])\d{7,}(?![\d,])");
glob _CURRENCY_BEFORE_RE = re.compile(r"(?i)(?:ksh|kes|sh)\.?\s*$");
glob _CURRENCY_AFTER_RE = re.compile(r"(?i)^\s*(?:/=|bob\b|ksh\b|kes\b|shillings?\b|sh\b)");
glob _LINK_TRAILING: str = ".,;:!?)]'\"";


obj Redacted {
    has display: str,  # masked text for UI and storage
        llm_text: str,  # neutral-token text, the only text the LLM sees
        fingerprint: str,  # HMAC over the keyed text: identical iff same identifiers + wording
        entities: list[dict[str, str]];  # kind, key, display, token per identifier
}


obj SenderIdentity {
    has key: str,  # HMAC sender key
        display: str,
        kind: str;  # SENDER_PHONE or SENDER_ID - safe to show the LLM
}

glob SENDER_PHONE: str = "a phone number",
     SENDER_ID: str = "a registered sender ID (e.g. a bank or telco name)",
     SENDER_UNKNOWN: str = "unknown";


"""HMAC key over a canonical identifier with the server-side secret."""
def hmac_key(canonical: str) -> str {
    secret = os.getenv("PESA_HMAC_SECRET", "");
    if not secret {
        raise RuntimeError("not_configured: PESA_HMAC_SECRET is not set on the server");
    }
    return hmac.new(secret.encode(), canonical.encode(), hashlib.sha256).hexdigest()[:32];
}


def _digits(raw: str) -> str {
    return "".join([c for c in raw if c.isdigit()]);
}


"""Canonical phone: 2547XXXXXXXX whether written +254, 254 or 07."""
def _canonical_phone(raw: str) -> str {
    d = _digits(raw);
    if d.startswith("0") and len(d) == 10 {
        d = "254" + d[1:];
    } elif len(d) == 9 and d[0] in "17" {
        d = "254" + d;
    }
    return "phone:" + d;
}


def _strip_scheme(link: str) -> str {
    return re.sub(r"(?i)^(?:https?://)?(?:www\.)?", "", link);
}


def _canonical(kind: str, raw: str) -> str {
    if kind == "PHONE" {
        return _canonical_phone(raw);
    }
    if kind == "LINK" {
        return "link:" + _strip_scheme(raw.lower()).rstrip("/");
    }
    if kind == "ACCOUNT" or kind == "NAME" {
        return kind.lower() + ":" + " ".join(raw.upper().split());
    }
    return kind.lower() + ":" + _digits(raw);
}


def _mask(kind: str, raw: str) -> str {
    if kind == "LINK" {
        host = _strip_scheme(raw).split("/")[0];
        return "link …" + host[-3:];
    }
    if kind == "NAME" {
        return " ".join([w[:1] + "***" for w in raw.split()]);
    }
    tail = raw.replace(" ", "").replace("-", "");
    return "…" + tail[-3:];
}


def _is_phone_sender(stripped: str) -> bool {
    return bool(
        _PHONE_RE.fullmatch(stripped)
        or (len(_digits(stripped)) >= 7 and re.fullmatch(r"[\d\s+()\-]+", stripped))
    );
}


"""What kind of sender this is, without revealing who: for the LLM."""
def sender_kind(raw: str) -> str {
    stripped = raw.strip();
    if not stripped {
        return SENDER_UNKNOWN;
    }
    return SENDER_PHONE if _is_phone_sender(stripped) else SENDER_ID;
}


"""Identify the message sender: a phone number or an alphanumeric sender ID."""
def identify_sender(raw: str) -> SenderIdentity {
    stripped = raw.strip();
    if sender_kind(stripped) == SENDER_PHONE {
        return SenderIdentity(
            key=hmac_key(_canonical_phone(stripped)),
            display=_mask("PHONE", stripped),
            kind=SENDER_PHONE
        );
    }
    return SenderIdentity(
        key=hmac_key("sender:" + stripped.upper()),
        display=stripped[:1] + "***",
        kind=SENDER_ID
    );
}


def _find_spans(text: str) -> list[tuple[int, int, str]] {
    spans: list[tuple[int, int, str]] = [];
    def claim(start: int, end: int, kind: str) {
        for (s, e, _) in spans {
            if start < e and s < end {
                return;
            }
        }
        spans.append((start, end, kind));
    }
    for m in _LINK_RE.finditer(text) {
        end = m.end();
        while end > m.start() and text[end - 1] in _LINK_TRAILING {
            end -= 1;
        }
        claim(m.start(), end, "LINK");
    }
    for m in _TILL_RE.finditer(text) {
        claim(m.start(1), m.end(1), "TILL");
    }
    for m in _ACCOUNT_RE.finditer(text) {
        claim(m.start(1), m.end(1), "ACCOUNT");
    }
    for m in _NAME_RE.finditer(text) {
        g = 1 if m.group(1) else 2;
        claim(m.start(g), m.end(g), "NAME");
    }
    for m in _PHONE_RE.finditer(text) {
        claim(m.start(), m.end(), "PHONE");
    }
    for m in _NUMBER_RE.finditer(text) {
        is_amount = _CURRENCY_BEFORE_RE.search(text[max(0, m.start() - 6):m.start()])
            or _CURRENCY_AFTER_RE.search(text[m.end():m.end() + 12]);
        if not is_amount {
            claim(m.start(), m.end(), "NUMBER");
        }
    }
    return sorted(spans);
}


"""Redact a raw message. The return value carries no raw identifier."""
def redact(text: str) -> Redacted {
    display = "";
    llm_text = "";
    keyed = "";
    entities: list[dict[str, str]] = [];
    token_for: dict[str, str] = {};  # HMAC key -> token, so repeats share a token
    per_kind: dict[str, int] = {};
    pos = 0;
    for (start, end, kind) in _find_spans(text) {
        raw = text[start:end];
        key = hmac_key(_canonical(kind, raw));
        masked = _mask(kind, raw);
        if key not in token_for {
            per_kind[kind] = per_kind.get(kind, 0) + 1;
            token_for[key] = f"[{kind}_{per_kind[kind]}]";
            entities.append(
                {"kind": kind, "key": key, "display": masked, "token": token_for[key]}
            );
        }
        plain = text[pos:start];
        display += plain + masked;
        llm_text += plain + token_for[key];
        keyed += plain + "[" + key + "]";
        pos = end;
    }
    rest = text[pos:];
    return Redacted(
        display=display + rest,
        llm_text=llm_text + rest,
        fingerprint=hmac_key("text:" + keyed + rest),
        entities=entities
    );
}


"""Template hash (GLOSSARY): sha256 of the normalised neutral-token text.

Token numbers and digits are blanked so the same template with different
identifiers or amounts hashes alike. Secret-independent; never used for
dedupe or ring linking.
"""
def template_hash(llm_text: str) -> str {
    blanked: str = re.sub(r"\[([A-Z]+)_\d+\]", r"[\1]", llm_text).lower();
    blanked = re.sub(r"\d", "0", blanked);
    norm = " ".join(blanked.split());
    return hashlib.sha256(norm.encode()).hexdigest()[:32];
}
