"""Guard - checks a message before the user acts on it (GLOSSARY: Guard).

Guard runs after ingestion (GuardMessage, kicked by IngestMessage) or on a
pasted message (Check). The LLM sees only neutral-token text and decides
per message which tools to call; every tool answers in tokens and counts,
never masked or raw identifiers. Labelled synthetic messages - matched on
their exact raw text at ingestion - are answered from
config/verdict_cache.json and marked `cached`; everything else hits the LLM.
After the verdict Guard writes SentBy, Mentions (pay targets only) and
MatchesPattern edges.
"""

import os;
import re;
import json;
import threading;
import from access {
    now,
    require_rate,
    require_secret,
    require_text
}
import from graph {
    MatchesPattern,
    Mentions,
    Message,
    PayTarget,
    Pattern,
    SentBy,
    Sender,
    all_messages,
    message_view
}
import from redaction {
    redact,
    sender_kind,
    sender_kind_choice,
    template_hash
}
import from labelled {
    config_path,
    labelled_key,
    verdict_cache
}
import from rings {
    apply_ring_rules,
    is_ring,
    known_legit_keys
}

# Identifier kinds that can be a pay target (GLOSSARY: Pay target).
glob PAY_KINDS: list[str] = ["PHONE", "TILL", "LINK"];

enum Risk: str {
    LOW = "low",
    MEDIUM = "medium",
    HIGH = "high"
}

enum ScamType: str {
    WRONG_NUMBER_REVERSAL = "wrong_number_reversal",
    FEE_BEFORE_LOAN = "fee_before_loan",
    FAKE_PRIZE_PROMO = "fake_prize_promo",
    FAKE_CONFIRMATION = "fake_confirmation",
    IMPERSONATION = "impersonation",
    FAKE_JOB_OR_VISA_FEE = "fake_job_or_visa_fee",
    SIM_SWAP_OTP_REQUEST = "sim_swap_otp_request",
    LEGIT_TRANSACTION = "legit_transaction",
    NONE = "none"
}

sem Risk.LOW = "Safe or ordinary: a genuine notice or harmless message.";
sem Risk.MEDIUM = "Suspicious: some scam signals, but not conclusive.";
sem Risk.HIGH = "Very likely a scam: do not pay, reply or share codes.";
sem ScamType.LEGIT_TRANSACTION = "A genuine transaction confirmation or service notice.";
sem ScamType.NONE = "Not a scam and not a transaction notice.";

"""The LLM's judgement of one message."""
obj Judgement {
    has risk: Risk,
        scam_type: ScamType,
        reasons: list[str],
        action: str,
        explanation_en: str,
        explanation_sw: str,
        pay_target_tokens: list[str] = [];
}

sem Judgement.reasons = "At most three short reasons, plain English, most important first.";
sem Judgement.action = "The one clear thing the reader should do now, in plain English.";
sem Judgement.explanation_en = "Two or three plain-English sentences a non-technical reader understands.";
sem Judgement.explanation_sw = """The same explanation in natural, everyday Kenyan Swahili as a
native speaker would say it - not a word-for-word translation and never Sheng.""";
sem Judgement.pay_target_tokens = """Tokens (e.g. [TILL_1], [PHONE_2]) the message asks the reader
to pay or send money to. Empty if it asks for no payment.""";

"""What a tool call reports about one token."""
obj EntityRef {
    has token: str,
        kind: str;
}

obj EntityReport {
    has identifiers: list[EntityRef],
        amounts: list[str],
        lender_mentions: list[str];
}

obj GraphEvidence {
    has token: str,
        known: bool,
        other_messages: int,
        other_senders: int,
        medium_or_high_reports: int,
        is_a_sender: bool,
        in_ring: bool = False,  # a pay target several senders asked people to pay
        known_legit: bool = False;  # on the known-legit list
}

obj LenderCheck {
    has name: str,
        found: bool,
        status: str,
        note: str;
}

obj SimilarReport {
    has same_template: int,
        by_risk: dict[str, int],
        scam_types: list[str];
}

"""State for the Guard run in progress; tools read it, never the LLM."""
obj GuardRun {
    has token_keys: dict[str, str],  # token -> HMAC key
        template: str,
        exclude_id: str,
        tools_used: list[str] = [];
}

obj GuardResult {
    has judgement: Judgement,
        tools_used: list[str],
        cached: bool;
}

glob _run: GuardRun | None = None,
     _lock: threading.Lock = threading.Lock(),
     _lenders: list[dict] | None = None;


def _record_tool_use(tool: str) {
    if _run is not None and tool not in _run.tools_used {
        _run.tools_used.append(tool);
    }
}


def _load_json(name: str) -> any {
    with open(config_path(name), encoding="utf-8") as f {
        return json.load(f);
    }
}


"""List the identifier tokens, amounts and lender names in a message."""
def extract_entities(message: str) -> EntityReport {
    _record_tool_use("extract_entities");
    refs = [
        EntityRef(token=m.group(0), kind=m.group(1))
        for m in re.finditer(r"\[([A-Z]+)_\d+\]", message)
    ];
    amounts = [str(a) for a in re.findall(r"(?i)(?:ksh|kes|sh)\.?\s?[\d,]+(?:\.\d+)?|[\d,]+\s?(?:bob|/=)", message)];
    lowered = message.lower();
    lenders = [str(l["name"]) for l in _lender_list() if str(l["name"]).lower() in lowered];
    return EntityReport(identifiers=refs, amounts=amounts, lender_mentions=lenders);
}
sem extract_entities = "List the identifier tokens, money amounts and lender names in the message.";
sem extract_entities.message = "The message text, exactly as given to you.";


"""What the shared graph already knows about a token's identifier."""
def lookup_graph(token: str) -> GraphEvidence {
    _record_tool_use("lookup_graph");
    key = _run.token_keys.get(token, "") if _run is not None else "";
    exclude = _run.exclude_id if _run is not None else "";
    if not key {
        return GraphEvidence(
            token=token, known=False, other_messages=0, other_senders=0,
            medium_or_high_reports=0, is_a_sender=False
        );
    }
    hits = [
        m for m in all_messages()
        if jid(m) != exclude
        and (m.sender_key == key or key in [e["key"] for e in m.entities])
    ];
    return GraphEvidence(
        token=token,
        known=len(hits) > 0,
        other_messages=len(hits),
        other_senders=len({m.sender_key for m in hits}),
        medium_or_high_reports=len(
            [m for m in hits if m.risk in [Risk.MEDIUM.value, Risk.HIGH.value]]
        ),
        is_a_sender=len([root -->[?:Sender, key == key]]) > 0,
        in_ring=len([t for t in [root -->[?:PayTarget, key == key]] if is_ring(t)]) > 0,
        known_legit=key in known_legit_keys()
    );
}
sem lookup_graph = """Look up an identifier token in the shared scam graph: how many other
messages and senders mention it, and how many of those were judged medium or high risk.""";
sem lookup_graph.token = "An identifier token from the message, e.g. [TILL_1] or [PHONE_1].";


def _lender_list -> list[dict] {
    global _lenders;
    if _lenders is None {
        _lenders = _load_json("lenders.json")["lenders"] as list[dict];
    }
    return _lenders as list[dict];
}


"""Check a lender name against the configured lender snapshot."""
def check_lender(name: str) -> LenderCheck {
    _record_tool_use("check_lender");
    for l in _lender_list() {
        if str(l["name"]).lower() == name.strip().lower() {
            return LenderCheck(
                name=name, found=True, status=str(l["status"]),
                note="Placeholder snapshot - verify before use."
            );
        }
    }
    return LenderCheck(
        name=name, found=False, status="unknown",
        note="Not in the lender snapshot - verify before use."
    );
}
sem check_lender = "Check whether a lender named in the message is in the lender snapshot, and its status.";
sem check_lender.name = "The lender name exactly as it appears in the message.";


"""How earlier messages with the same template were judged."""
def similar_messages -> SimilarReport {
    _record_tool_use("similar_messages");
    template = _run.template if _run is not None else "";
    exclude = _run.exclude_id if _run is not None else "";
    same = [
        m for m in all_messages()
        if m.template_hash == template and jid(m) != exclude and m.status == "analysed"
    ];
    by_risk: dict[str, int] = {};
    for m in same {
        by_risk[m.risk] = by_risk.get(m.risk, 0) + 1;
    }
    return SimilarReport(
        same_template=len(same),
        by_risk=by_risk,
        scam_types=sorted({m.scam_type for m in same})
    );
}
sem similar_messages = """Find earlier messages with the same wording template as this one and
how they were judged.""";


def judge(message: str, sender_kind: str) -> Judgement by llm(
    tools=[extract_entities, lookup_graph, check_lender, similar_messages],
    temperature=0.1,
    max_react_iterations=6
);
sem judge = """You are Guard, a Kenyan mobile-money scam checker. Judge one SMS before the
reader acts on it. Phone numbers, tills, paybills, accounts, names and links are replaced by
tokens like [PHONE_1]; never guess the real values. Call a tool only when its answer could
change your judgement - e.g. lookup_graph for a pay target or sender, similar_messages for a
familiar template, check_lender when a lender is named. Common scams: wrong-number reversal,
fee before loan, fake prize, fake payment confirmation, impersonation, fake job or visa fee,
PIN/OTP or SIM-swap requests. A genuine confirmation or notice that asks for nothing risky is
low risk (legit_transaction); do not cry wolf.""";
sem judge.message = "The SMS text with identifiers replaced by tokens.";
sem judge.sender_kind = """What kind of sender sent it: a phone number, a registered sender ID, or
unknown. Real mobile-money and bank confirmations come from registered sender IDs, and a
'confirmation' from a phone number is a strong sign of a fake - but sender IDs can be spoofed,
so the content decides.""";


def _judgement_from(d: dict) -> Judgement {
    return Judgement(
        risk=Risk(d["risk"]),
        scam_type=ScamType(d["scam_type"]),
        reasons=list(d["reasons"]),
        action=str(d["action"]),
        explanation_en=str(d["explanation_en"]),
        explanation_sw=str(d["explanation_sw"]),
        pay_target_tokens=list(d.get("pay_target_tokens", []))
    );
}


"""Hold any Judgement, cached or live, to the Verdict contract."""
def _tidy(judgement: Judgement, entities: list[dict[str, str]]) -> Judgement {
    known = [e["token"] for e in entities];
    judgement.reasons = [r.strip() for r in judgement.reasons if r.strip()][:3];
    judgement.pay_target_tokens = [t for t in judgement.pay_target_tokens if t in known];
    return judgement;
}


"""Judge one redacted message: the cache for a labelled message, else the LLM."""
def run_guard(
    llm_text: str,
    entities: list[dict[str, str]],
    template: str,
    exclude_id: str,
    labelled: str,
    sender_kind: str
) -> GuardResult {
    global _run;
    if labelled and labelled in verdict_cache() {
        cached = _judgement_from(verdict_cache()[labelled] as dict);
        return GuardResult(judgement=_tidy(cached, entities), tools_used=[], cached=True);
    }
    with _lock {
        _run = GuardRun(
            token_keys={e["token"]: e["key"] for e in entities},
            template=template,
            exclude_id=exclude_id
        );
        try {
            live = judge(llm_text, sender_kind);
            used = list(_run.tools_used);
        } finally {
            _run = None;
        }
    }
    return GuardResult(judgement=_tidy(live, entities), tools_used=used, cached=False);
}


"""Store the Verdict on the message, write its edges and apply the ring
rules. Runs once per message (GuardMessage only acts while `analysing`)."""
def apply_verdict(msg: Message, result: GuardResult) {
    j = result.judgement;
    msg.risk = j.risk.value;
    msg.scam_type = j.scam_type.value;
    msg.reasons = j.reasons;
    msg.action = j.action;
    msg.explanation_en = j.explanation_en;
    msg.explanation_sw = j.explanation_sw;
    msg.tools_used = result.tools_used;
    msg.cached = result.cached;
    msg.status = "analysed";
    msg.analysed_at = str(now());

    if not [msg ->:SentBy:->] {
        for s in [msg <--[?:Sender]] {
            msg +>:SentBy:+> s;
        }
    }
    linked = {t.key for t in [msg ->:Mentions:->]};
    for e in msg.entities {
        if e["kind"] not in PAY_KINDS
        or e["token"] not in j.pay_target_tokens
        or e["key"] in linked {
            continue;
        }
        found = [root -->[?:PayTarget, key == e["key"]]];
        target = found[0] if found else (
            root ++> PayTarget(key=e["key"], kind=e["kind"], display=e["display"])
        )[0];
        msg +>:Mentions:+> target;
        linked.add(e["key"]);
    }
    if j.scam_type != ScamType.NONE and not [msg ->:MatchesPattern:->] {
        for p in [root -->[?:Pattern, name == j.scam_type.value]] {
            msg +>:MatchesPattern:+> p;
        }
    }
    apply_ring_rules(msg);
}


"""Run Guard on one stored message; failures mark it `failed`."""
def guard_message(msg: Message) {
    try {
        result = run_guard(
            msg.llm_text,
            msg.entities,
            msg.template_hash,
            jid(msg),
            msg.cache_key,
            msg.sender_kind
        );
        apply_verdict(msg, result);
    } except Exception as e {
        msg.status = "failed";
        print(f"guard failed for {jid(msg)}: {type(e).__name__}");
    }
}


"""Run Guard for an ingested message (kicked by IngestMessage after its
response). Webhook secret. Runs only while the message is `analysing`, so a
repeated kick never re-analyses.
"""
walker:pub GuardMessage {
    has secret: str = "",
        message_id: str = "",
        reports: list[dict[str, any]] = [];

    can run with Root entry {
        require_secret("PESA_WEBHOOK_SECRET", self.secret);
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
        if target.status == "analysing" {
            guard_message(target);
        }
        report message_view(target);
    }
}


"""Admin: analyse messages still `analysing` or `failed` (e.g. a kick that
never arrived). Admin secret.
"""
walker:pub GuardPending {
    has secret: str = "",
        limit: int = 5,
        reports: list[dict[str, any]] = [];

    can run with Root entry {
        require_secret("PESA_ADMIN_SECRET", self.secret);
        pending = [m for m in all_messages() if m.status in ["analysing", "failed"]];
        for m in pending[:self.limit] {
            guard_message(m);
            report message_view(m);
        }
    }
}


"""Check a pasted message without storing it. Client token; rate limited."""
walker:pub Check {
    has token: str = "",
        text: str = "",
        sender: str = "",  # optional: only its kind reaches Guard
        from_kind: str = "",  # used only without `sender`: "phone" | "id"
        reports: list[dict[str, any]] = [];

    can run with Root entry {
        require_secret("PESA_CLIENT_TOKEN", self.token);
        require_text(self.text);
        require_rate("check", "PESA_CHECK_RATE_MAX", 10);
        redacted = redact(self.text);
        result = run_guard(
            redacted.llm_text,
            redacted.entities,
            template_hash(redacted.llm_text),
            "",
            labelled_key(self.text),
            sender_kind(self.sender) if self.sender.strip() else sender_kind_choice(self.from_kind)
        );
        verdict = result.judgement;
        report {
            "display": redacted.display,
            "risk": verdict.risk.value,
            "scam_type": verdict.scam_type.value,
            "reasons": verdict.reasons,
            "action": verdict.action,
            "explanation_en": verdict.explanation_en,
            "explanation_sw": verdict.explanation_sw,
            "entities": [
                {"kind": e["kind"], "display": e["display"]} for e in redacted.entities
            ],
            "ring_id": "",
            "tools_used": result.tools_used,
            "cached": result.cached
        };
    }
}
