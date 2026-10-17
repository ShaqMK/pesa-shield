"""Rings (GLOSSARY: Ring) and the graph view.

Rules (SPEC: Ring rules):
- Senders are linked only through a shared pay target (Sender ─LinkedTo─>
  PayTarget), and only by medium/high messages - template similarity never
  links anything.
- A pay target linked to at least RING_MIN_SENDERS senders is a ring, unless
  it is on the known-legit list (config/known_legit_targets.json).
- A ring's report count includes only medium/high messages.
- When a ring forms or grows, every medium/high message to its pay target,
  and every other medium/high message from its member senders, joins it:
  medium is escalated to high and the evidence reads "also reported from N
  other numbers" - retroactively for earlier messages.
- Everything here is recomputed from the graph, so re-running it (e.g. a
  GuardPending retry) never double-counts.
"""

import os;
import json;
import from graph {
    LinkedTo,
    Mentions,
    Message,
    PayTarget,
    Sender,
    message_view
}
import from labelled {
    config_path
}
import from redaction {
    identifier_key
}

glob RING_MIN_SENDERS: int = 3,
     RING_RISKS: list[str] = ["medium", "high"],
     MAX_GRAPH_NODES: int = 20,
     _legit_keys_by_secret: dict[str, set[str]] = {};


"""HMAC keys of the known-legit pay targets. The config holds plain
placeholder identifiers; keys are computed (and cached) per HMAC secret."""
def known_legit_keys -> set[str] {
    secret = os.getenv("PESA_HMAC_SECRET", "");
    if secret not in _legit_keys_by_secret {
        with open(config_path("known_legit_targets.json"), encoding="utf-8") as f {
            targets = (json.load(f) as dict)["targets"] as list[dict];
        }
        _legit_keys_by_secret[secret] = {
            identifier_key(str(t["kind"]), str(t["value"])) for t in targets
        };
    }
    return _legit_keys_by_secret[secret];
}


def is_medium_or_high(m: Message) -> bool {
    return m.risk in RING_RISKS;
}


def ring_id_of(target: PayTarget) -> str {
    return "ring-" + target.key[:8];
}


def linked_senders(target: PayTarget) -> list[Sender] {
    return [target <-:LinkedTo:<-];
}


def ring_reports(target: PayTarget) -> list[Message] {
    return [m for m in [target <-:Mentions:<-] if is_medium_or_high(m)];
}


def target_label(t: PayTarget) -> str {
    return t.kind.lower() + " " + t.display;
}


def is_ring(target: PayTarget) -> bool {
    return target.key not in known_legit_keys()
    and len(linked_senders(target)) >= RING_MIN_SENDERS;
}


"""Record that a medium/high message's sender asked people to pay `target`;
the link's count is recomputed, so repeating this is harmless."""
def link_sender(msg: Message, target: PayTarget) {
    for sender in [msg <--[?:Sender]] {
        if not [edge sender ->:LinkedTo:-> target] {
            sender +>:LinkedTo:+> target;
        }
        for link in [edge sender ->:LinkedTo:-> target] {
            link.count = len(
                [m for m in ring_reports(target) if m.sender_key == sender.key]
            );
        }
    }
}


"""Bring every medium/high message to `target`, and every other medium/high
message from its member senders, into its ring - if it is one."""
def update_ring(target: PayTarget) {
    if not is_ring(target) {
        return;
    }
    rid = ring_id_of(target);
    members = linked_senders(target);
    members_msgs = [m for s in members for m in [s -->[?:Message]] if is_medium_or_high(m)];
    candidates = ring_reports(target) + members_msgs;
    joined: dict[str, Message] = {jid(m): m for m in candidates};
    for m in joined.values() {
        if m.ring_id and m.ring_id != rid {
            continue;  # already evidenced by another ring
        }
        m.ring_id = rid;
        m.ring_others = len(members) - 1;
        if m.risk == "medium" {
            m.risk = "high";
            m.escalated = True;
        }
    }
}


"""After a verdict: link the sender to the message's pay targets (medium/high
only) and form or grow rings."""
def apply_ring_rules(msg: Message) {
    if msg.risk not in RING_RISKS {
        return;
    }
    for target in [msg ->:Mentions:->] {
        link_sender(msg, target);
        update_ring(target);
    }
}


def _target_node(t: PayTarget) -> dict[str, any] {
    return {
        "id": jid(t),
        "kind": "target",
        "label": target_label(t),
        "count": len(ring_reports(t)),
        "ring_id": ring_id_of(t) if is_ring(t) else ""
    };
}


"""Read-only: rings plus a small graph (at most MAX_GRAPH_NODES nodes) of
pay targets and the senders linked to them, rings first."""
walker:pub GraphView {
    has reports: list[dict[str, any]] = [];

    can collect with Root entry {
        targets = [t for t in [root -->[?:PayTarget]] if linked_senders(t)];
        targets = sorted(
            targets,
            key=lambda t: PayTarget : (is_ring(t), len(ring_reports(t))),
            reverse=True
        );
        rings: list[dict[str, any]] = [];
        nodes: list[dict[str, any]] = [];
        edges: list[dict[str, any]] = [];
        seen: set[str] = set();
        for t in targets {
            senders = linked_senders(t);
            if is_ring(t) {
                rings.append({
                    "ring_id": ring_id_of(t),
                    "target_id": jid(t),
                    "target": target_label(t),
                    "senders": len(senders),
                    "reports": len(ring_reports(t))
                });
            }
            if len(nodes) + 1 + len(senders) > MAX_GRAPH_NODES {
                continue;
            }
            nodes.append(_target_node(t));
            for s in senders {
                if jid(s) not in seen {
                    seen.add(jid(s));
                    nodes.append({
                        "id": jid(s),
                        "kind": "sender",
                        "label": s.display,
                        "count": len([m for m in [s -->[?:Message]] if is_medium_or_high(m)]),
                        "ring_id": ""
                    });
                }
                for link in [edge s ->:LinkedTo:-> t] {
                    edges.append(
                        {"from": jid(s), "to": jid(t), "kind": "LinkedTo", "count": link.count}
                    );
                }
            }
        }
        report {"rings": rings, "nodes": nodes, "edges": edges};
    }
}


"""Read-only: the messages behind a graph node (a sender's messages, or the
messages that ask people to pay a target), newest first."""
walker:pub NodeMessages {
    has node_id: str = "",
        reports: list[dict[str, any]] = [];

    can collect with Root entry {
        target: any = None;
        try {
            target = jobj(self.node_id);
        } except Exception {
            target = None;
        }
        msgs: list[Message] = [];
        if isinstance(target, Sender) {
            msgs = [target -->[?:Message]];
        } elif isinstance(target, PayTarget) {
            msgs = [target <-:Mentions:<-];
        }
        for m in sorted(msgs, key=lambda m: Message : float(m.created_at), reverse=True) {
            report message_view(m);
        }
    }
}
