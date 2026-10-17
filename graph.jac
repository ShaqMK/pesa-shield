"""The shared graph (SPEC: Graph model). Only redacted data lives here.

Sender ──> Message           (untyped: the feed reads senders' messages)
Message ─SentBy─> Sender      written by Guard after the verdict
Message ─Mentions─> PayTarget written by Guard after the verdict (pay targets only)
Message ─MatchesPattern─> Pattern
Sender ─LinkedTo─> PayTarget  a medium/high message from that sender asked
                              people to pay that target (rings.jac)
"""

import from taxonomy {
    PATTERN_TAXONOMY
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
        status: str,  # analysing -> analysed | failed
        created_at: str,
        sender_kind: str = "unknown",  # phone number vs registered sender ID
        template_hash: str = "",
        cache_key: str = "",  # set only for labelled synthetic messages
        # Verdict, filled in by Guard.
        risk: str = "",
        scam_type: str = "",
        reasons: list[str] = [],
        action: str = "",
        explanation_en: str = "",
        explanation_sw: str = "",
        ring_id: str = "",
        ring_others: int = 0,  # other numbers in its ring (evidence)
        escalated: bool = False,  # risk raised to high because of a ring
        tools_used: list[str] = [],
        cached: bool = False,
        analysed_at: str = "";
}

"""A till, paybill, phone number or link that a message asks you to pay
(GLOSSARY: Pay target). Guard links messages to them via Mentions."""
node PayTarget {
    has key: str,  # HMAC key of the identifier
        kind: str,
        display: str;
}

node Pattern {
    has name: str,  # taxonomy label, e.g. fee_before_loan
        title: str,
        description: str;
}

edge SentBy: Message --> Sender {}

edge Mentions: Message --> PayTarget {}

edge MatchesPattern: Message --> Pattern {}

edge LinkedTo: Sender --> PayTarget {
    has count: int = 0;  # medium/high messages from the sender to the target
}


def all_messages -> list[Message] {
    return [root -->[?:Sender]-->[?:Message]];
}


def pattern_count -> int {
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


"""At most three reasons; ring evidence, when present, takes the last slot."""
def verdict_reasons(m: Message) -> list[str] {
    if m.ring_id {
        return m.reasons[:2] + [
            f"Linked to a scam ring: also reported from {m.ring_others} other numbers."
        ];
    }
    return m.reasons[:3];
}


"""The Swahili explanation, with the ring evidence when there is one."""
def explanation_sw(m: Message) -> str {
    if m.ring_id {
        return m.explanation_sw + f" Ujumbe huu unahusishwa na genge la utapeli: umeripotiwa pia kutoka kwa nambari nyingine {m.ring_others}.";
    }
    return m.explanation_sw;
}


"""Feed/API view of a message and its Verdict (masked values only)."""
def message_view(m: Message) -> dict[str, any] {
    return {
        "id": jid(m),
        "display": m.display,
        "sender_display": m.sender_display,
        "status": m.status,
        "created_at": m.created_at,
        "risk": m.risk,
        "scam_type": m.scam_type,
        "reasons": verdict_reasons(m),
        "action": m.action,
        "explanation_en": m.explanation_en,
        "explanation_sw": explanation_sw(m),
        "entities": [{"kind": e["kind"], "display": e["display"]} for e in m.entities],
        "ring_id": m.ring_id,
        "escalated": m.escalated,
        "tools_used": m.tools_used,
        "cached": m.cached
    };
}
