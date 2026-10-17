"""Recovery - helps after a scam (GLOSSARY: Recovery, Case).

StartCase gathers the case messages, builds a typed timeline, extracts facts
exactly as present in the (masked) messages, drafts a typed Report and stops
at `awaiting_approval`. Only the human finalizes it (ApproveCase) or drops it
(DiscardCase); nothing is ever sent anywhere - the approved text is for the
user to copy and send themselves.

The LLM drafts only the narrative, from neutral-token text; facts and the
timeline are attached by code, so their values are exact and the LLM never
sees a masked value. If the LLM is unavailable a template narrative is used.
"""

import re;
import json;
import from datetime {
    datetime
}
import from access {
    now,
    require_rate,
    require_secret
}
import from model {
    Case,
    Message,
    PartOfCase,
    Sender
}
import from labelled {
    config_path
}

glob MAX_CASE_MESSAGES: int = 10,
     AWAITING: str = "awaiting_approval",
     APPROVED: str = "approved",
     DISCARDED: str = "discarded",
     _AMOUNT_RE = re.compile(
         r"(?i)\b(?:ksh|kes|sh|shilingi)\.?\s?\d[\d,]*(?:\.\d{1,2})?|\b\d[\d,]*\s?(?:bob\b|/=)"
     ),
     _TXN_CODE_RE = re.compile(r"\b(?=[A-Z0-9]*\d)(?=[A-Z0-9]*[A-Z])[A-Z0-9]{10}\b"),
     _channels: list[dict[str, any]] | None = None,
     SCAM_WORDS: dict[str, list[str]] = {
         "wrong_number_reversal": ["wrong-number reversal", "kurudisha pesa iliyotumwa kimakosa"],
         "fee_before_loan": ["fee-before-loan", "ada ya mkopo kabla ya kupewa mkopo"],
         "fake_prize_promo": ["fake prize", "zawadi bandia"],
         "fake_confirmation": ["fake payment confirmation", "uthibitisho bandia wa malipo"],
         "impersonation": ["impersonation", "kujifanya mtu au taasisi nyingine"],
         "fake_job_or_visa_fee": ["fake job or visa fee", "ada ya kazi au viza bandia"],
         "sim_swap_otp_request": ["SIM swap / code request", "kubadilisha laini au kuomba nambari ya siri"]
     };

"""One step of what happened, from one message."""
obj TimelineEvent {
    has at: str,
        message_id: str,
        summary: str,  # the masked message text
        risk: str,
        scam_type: str;
}

"""A fact exactly as it appears in the masked messages."""
obj Fact {
    has kind: str,  # amount | transaction_code | phone | till | link | account | name | number
        value: str;
}

"""A drafted Report body in both languages, and who wrote the narrative."""
obj CaseDraft {
    has body_en: str,
        body_sw: str,
        drafted_by: str;  # "llm" or "template"
}

"""The LLM's part of the Report: the narrative only, in both languages."""
obj ReportDraft {
    has narrative_en: str,
        narrative_sw: str;
}

sem ReportDraft.narrative_en = """A short first-person report (4-6 sentences) of what happened
and that money was lost, in plain English. Refer to people, numbers and tills only in words
("the sender", "the till") - no tokens, no invented details.""";
sem ReportDraft.narrative_sw = """The same report in natural, everyday Kenyan Swahili as a native
speaker would write it - not a word-for-word translation and never Sheng.""";


def draft_narrative(timeline: list[str], scam_type: str) -> ReportDraft by llm(temperature=0.2);
sem draft_narrative = """Draft the narrative of a scam report a Kenyan mobile-money user will
send to the authorities themselves. Use only what the messages show.""";
sem draft_narrative.timeline = "The scam messages in order, with identifiers replaced by tokens.";
sem draft_narrative.scam_type = "The scam pattern Guard matched, e.g. fee_before_loan.";


def report_channels -> list[dict[str, any]] {
    if _channels is None {
        with open(config_path("report_channels.json"), encoding="utf-8") as f {
            _channels = (json.load(f) as dict[str, any])["channels"] as list[dict[str, any]];
        }
    }
    return _channels as list[dict[str, any]];
}


def channel_labels -> list[str] {
    return [str(c["label"]) for c in report_channels()];
}


"""The start message plus the same sender's other medium/high messages,
oldest first (at most MAX_CASE_MESSAGES). Other people's messages - even to
the same pay target - stay out of this user's case."""
def gather_messages(start: Message) -> list[Message] {
    found: dict[str, Message] = {jid(start): start};
    for s in [start <--[?:Sender]] {
        for m in [s -->[?:Message]] {
            if m.risk in ["medium", "high"] {
                found[jid(m)] = m;
            }
        }
    }
    msgs = sorted(found.values(), key=lambda (m: Message) -> float { float(m.created_at); });
    return msgs[-MAX_CASE_MESSAGES:];
}


def build_timeline(msgs: list[Message]) -> list[TimelineEvent] {
    return [
        TimelineEvent(
            at=datetime.fromtimestamp(float(m.created_at)).isoformat(timespec="minutes"),
            message_id=jid(m),
            summary=m.display,
            risk=m.risk,
            scam_type=m.scam_type
        )
        for m in msgs
    ];
}


"""Amounts, transaction codes and identifiers, exactly as present (masked)."""
def extract_facts(msgs: list[Message]) -> list[Fact] {
    facts: list[Fact] = [];
    seen: set[str] = set();
    def add(kind: str, value: str) {
        if kind + "|" + value not in seen {
            seen.add(kind + "|" + value);
            facts.append(Fact(kind=kind, value=value));
        }
    }
    for m in msgs {
        for a in _AMOUNT_RE.findall(m.display) {
            add("amount", str(a));
        }
        for c in _TXN_CODE_RE.findall(m.display) {
            add("transaction_code", str(c));
        }
        for e in m.entities {
            add(str(e["kind"]).lower(), str(e["display"]));
        }
    }
    return facts;
}


def _template_draft(scam_type: str) -> ReportDraft {
    words = SCAM_WORDS.get(scam_type, ["scam", "utapeli"]);
    return ReportDraft(
        narrative_en=f"I received the messages below, which appear to be a {words[0]} scam. "
        + "I followed the instructions and lost money. "
        + "I am reporting this so the numbers and pay targets involved can be investigated and blocked.",
        narrative_sw=f"Nilipokea jumbe zilizo hapa chini, ambazo zinaonekana kuwa utapeli wa {words[1]}. "
        + "Nilifuata maelekezo yake na nikapoteza pesa. "
        + "Ninaripoti ili nambari na mahali pa malipo vilivyohusika vichunguzwe na kuzuiwa."
    );
}


def _details(facts: list[Fact], timeline: list[TimelineEvent], lang: str) -> str {
    nl = chr(10);
    heads = ["Details (masked, as they appear in the messages):", "What happened:"] if lang == "en"
    else ["Maelezo (yamefichwa sehemu, kama yalivyo kwenye jumbe):", "Mfuatano wa matukio:"];
    lines: list[str] = [heads[0]] + [f"- {f.kind.replace('_', ' ')}: {f.value}" for f in facts];
    lines += ["", heads[1]] + [f"- {t.at}: {t.summary}" for t in timeline];
    return nl.join(lines);
}


"""Compose a draft Report body: narrative (LLM or template) + exact details."""
def draft_bodies(msgs: list[Message], facts: list[Fact], timeline: list[TimelineEvent], scam_type: str) -> CaseDraft {
    drafted_by = "llm";
    try {
        draft = draft_narrative([t.at + ": " + m.llm_text for (t, m) in zip(timeline, msgs)], scam_type);
    } except Exception {
        draft = _template_draft(scam_type);
        drafted_by = "template";
    }
    nl = chr(10);
    return CaseDraft(
        body_en=draft.narrative_en.strip() + nl + nl + _details(facts, timeline, "en"),
        body_sw=draft.narrative_sw.strip() + nl + nl + _details(facts, timeline, "sw"),
        drafted_by=drafted_by
    );
}


def _final_text(recipients: list[str], body: str, lang: str) -> str {
    nl = chr(10);
    to = "To: " if lang == "en" else "Kwa: ";
    footer = "Prepared with Pesa Shield - a decision aid, not legal advice. Confirm the reporting channel before sending."
    if lang == "en"
    else "Imeandaliwa kwa Pesa Shield - msaada wa kufanya uamuzi, si ushauri wa kisheria. Thibitisha njia ya kuripoti kabla ya kutuma.";
    return to + "; ".join(recipients) + nl + nl + body.strip() + nl + nl + footer;
}


def case_view(c: Case) -> dict[str, any] {
    return {
        "id": jid(c),
        "status": c.status,
        "created_at": c.created_at,
        "scam_type": c.scam_type,
        "message_ids": [jid(m) for m in [c <-:PartOfCase:<-]],
        "timeline": c.timeline,
        "facts": c.facts,
        "recipients": c.recipients,
        "available_recipients": channel_labels(),
        "body_en": c.body_en,
        "body_sw": c.body_sw,
        "drafted_by": c.drafted_by,
        "edited": c.edited,
        "final_text_en": c.final_text_en,
        "final_text_sw": c.final_text_sw
    };
}


def _lookup(object_id: str) -> any {
    try {
        return jobj(object_id);
    } except Exception {
        return None;
    }
}


def _load_case(case_id: str) -> Case {
    found = _lookup(case_id);
    if not isinstance(found, Case) {
        raise ValueError("invalid: case not found");
    }
    return found as Case;
}


def _require_awaiting(c: Case) {
    if c.status != AWAITING {
        raise ValueError(f"invalid: case is {c.status}, not awaiting approval");
    }
}


"""Start a Case from a message ("I lost money"). Client token; rate limited.
Returns the case at `awaiting_approval`. A message already in a case that is
still awaiting approval returns that case instead of a second one."""
walker:pub StartCase {
    has token: str = "",
        message_id: str = "",
        reports: list[dict[str, any]] = [];

    can start with Root entry {
        (given, self.token) = (self.token, "");  # never echoed back
        require_secret("PESA_CLIENT_TOKEN", given);
        found = _lookup(self.message_id);
        if not isinstance(found, Message) {
            raise ValueError("invalid: message not found");
        }
        start = found as Message;
        if start.status != "analysed" {
            raise ValueError("invalid: wait until Guard has checked this message");
        }
        for open_case in [start ->:PartOfCase:->[?:Case]] {
            if open_case.status == AWAITING {
                report case_view(open_case);
                disengage;
            }
        }
        require_rate("case", "PESA_CASE_RATE_MAX", 5);
        msgs = gather_messages(start);
        timeline = build_timeline(msgs);
        facts = extract_facts(msgs);
        draft = draft_bodies(msgs, facts, timeline, start.scam_type);
        c = Case(
            created_at=str(now()),
            status=AWAITING,
            scam_type=start.scam_type,
            timeline=[t.__dict__ for t in timeline],
            facts=[f.__dict__ for f in facts],
            recipients=channel_labels(),
            body_en=draft.body_en,
            body_sw=draft.body_sw,
            drafted_by=draft.drafted_by
        );
        root ++> c;
        for m in msgs {
            m +>:PartOfCase:+> c;
        }
        report case_view(c);
    }
}


"""Read-only: one case."""
walker:pub GetCase {
    has case_id: str = "",
        reports: list[dict[str, any]] = [];

    can fetch with Root entry {
        report case_view(_load_case(self.case_id));
    }
}


"""Read-only: all cases, newest first (summary fields)."""
walker:pub ListCases {
    has reports: list[dict[str, any]] = [];

    can collect with Root entry {
        for c in sorted([root -->[?:Case]], key=lambda (c: Case) -> float { float(c.created_at); }, reverse=True) {
            report {
                "id": jid(c),
                "status": c.status,
                "created_at": c.created_at,
                "scam_type": c.scam_type,
                "messages": len([c <-:PartOfCase:<-])
            };
        }
    }
}


"""Edit a draft. Client token. Only the fields sent are changed (an empty
recipient list clears them; approve then asks for one). The case stays at
`awaiting_approval`; editing never finalizes it."""
walker:pub EditCase {
    has token: str = "",
        case_id: str = "",
        body_en: str | None = None,
        body_sw: str | None = None,
        recipients: list[str] | None = None,
        reports: list[dict[str, any]] = [];

    can edit with Root entry {
        (given, self.token) = (self.token, "");  # never echoed back
        require_secret("PESA_CLIENT_TOKEN", given);
        c = _load_case(self.case_id);
        _require_awaiting(c);
        if self.recipients is not None {
            if [r for r in self.recipients if r not in channel_labels()] {
                raise ValueError("invalid: recipients must be configured channel labels");
            }
            if self.recipients != c.recipients {
                c.recipients = self.recipients;
                c.edited = True;
            }
        }
        if self.body_en is not None and self.body_en != c.body_en {
            c.body_en = self.body_en;
            c.edited = True;
        }
        if self.body_sw is not None and self.body_sw != c.body_sw {
            c.body_sw = self.body_sw;
            c.edited = True;
        }
        report case_view(c);
    }
}


"""Approve a draft: the only way a case is finalized. Client token. Exposes
the final text to copy; nothing is sent."""
walker:pub ApproveCase {
    has token: str = "",
        case_id: str = "",
        reports: list[dict[str, any]] = [];

    can approve with Root entry {
        (given, self.token) = (self.token, "");  # never echoed back
        require_secret("PESA_CLIENT_TOKEN", given);
        c = _load_case(self.case_id);
        _require_awaiting(c);
        if not c.recipients {
            raise ValueError("invalid: choose at least one recipient");
        }
        if not c.body_en.strip() or not c.body_sw.strip() {
            raise ValueError("invalid: the report text is empty");
        }
        c.final_text_en = _final_text(c.recipients, c.body_en, "en");
        c.final_text_sw = _final_text(c.recipients, c.body_sw, "sw");
        c.status = APPROVED;
        c.decided_at = str(now());
        report case_view(c);
    }
}


"""Discard a draft. Client token. Nothing is kept for sending."""
walker:pub DiscardCase {
    has token: str = "",
        case_id: str = "",
        reports: list[dict[str, any]] = [];

    can discard with Root entry {
        (given, self.token) = (self.token, "");  # never echoed back
        require_secret("PESA_CLIENT_TOKEN", given);
        c = _load_case(self.case_id);
        _require_awaiting(c);
        c.status = DISCARDED;
        c.decided_at = str(now());
        report case_view(c);
    }
}
