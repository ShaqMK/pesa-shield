"""Integration checks (spawn walkers on root).

Per the spec's testing decisions, tests go through walkers and assert on
reports; no internals are tested directly. The only stand-in is the LLM
boundary: Guard's `judge` is replaced by a fixed answer so no model is called.
"""

import os;
import guard as G;
import from guard {
    GuardMessage,
    Judgement,
    Risk,
    ScamType
}
import from rings {
    GraphView
}


def _use_test_secrets {
    os.environ["PESA_WEBHOOK_SECRET"] = "test-webhook-secret";
    os.environ["PESA_ADMIN_SECRET"] = "test-admin-secret";
    os.environ["PESA_HMAC_SECRET"] = "test-hmac-secret";
    os.environ["PESA_SELF_URL"] = "off";
}


"""Integration check 1: wrong or missing credential is rejected at every tier."""
test "wrong or missing credential is rejected" {
    _use_test_secrets();
    attempts = [
        ("webhook wrong", IngestMessage(secret="nope", sender="+254700111222", text="hi")),
        ("webhook missing", IngestMessage(sender="+254700111222", text="hi")),
        ("seed wrong", Seed(secret="nope")),
        ("seed missing", Seed()),
        ("seed with webhook secret", Seed(secret="test-webhook-secret")),
        ("reset wrong", Reset(secret="nope")),
        ("reset missing", Reset())
    ];
    for (name, w) in attempts {
        err = "";
        try {
            root spawn w;
        } except RuntimeError as e {
            err = str(e);
        }
        assert "forbidden" in err, (name, err);
    }
}

test "webhook creates message and returns analysing" {
    _use_test_secrets();
    w = root spawn IngestMessage(
        secret="test-webhook-secret",
        sender="+254700111222",
        text="fee before loan scam text 0700123456"
    );
    assert len(w.reports) == 1;
    assert w.reports[0]["status"] == "analysing";
    assert w.reports[0]["id"] != "";
}

test "webhook is idempotent on identical message" {
    _use_test_secrets();
    a = root spawn IngestMessage(secret="test-webhook-secret", sender="+254700111222", text="dedupe me 0700123456");
    b = root spawn IngestMessage(secret="test-webhook-secret", sender="+254700111222", text="dedupe me 0700123456");
    assert a.reports[0]["id"] == b.reports[0]["id"], ("dedupe must return the existing id", a.reports, b.reports);
}

test "feed returns messages newest first with analysing status" {
    _use_test_secrets();
    a = root spawn IngestMessage(secret="test-webhook-secret", sender="+254700111222", text="msg one 0700123456");
    b = root spawn IngestMessage(secret="test-webhook-secret", sender="+254700444555", text="msg two 0711555666");
    feed = root spawn WebFeed(limit=50);
    assert len(feed.reports) >= 2;
    for r in feed.reports {
        assert r["status"] == "analysing";
    }
    ids = [r["id"] for r in feed.reports];
    older = a.reports[0]["id"];
    newer = b.reports[0]["id"];
    assert ids.index(newer) < ids.index(older), "feed must be newest first";
}


"""A fixed medium-risk judgement naming the message's till as the pay target."""
def _medium_fee_judge(message: str, sender_kind: str) -> Judgement {
    return Judgement(
        risk=Risk.MEDIUM,
        scam_type=ScamType.FEE_BEFORE_LOAN,
        reasons=["Asks for a fee before the loan", "Urgent deadline", "Pays a till"],
        action="Do not pay.",
        explanation_en="Fee first is a scam sign.",
        explanation_sw="Kulipa ada kwanza ni ishara ya utapeli.",
        pay_target_tokens=["[TILL_1]"]
    );
}


def _ingest_and_guard(sender: str, text: str) -> str {
    w = root spawn IngestMessage(secret="test-webhook-secret", sender=sender, text=text);
    mid = w.reports[0]["id"];
    root spawn GuardMessage(secret="test-webhook-secret", message_id=mid);
    return mid;
}


"""Integration check 2: three senders sharing one pay target form a ring;
earlier medium messages escalate with evidence; same wording alone links
nothing."""
test "shared pay target forms a ring and escalates earlier messages" {
    _use_test_secrets();
    real_judge = G.judge;
    G.judge = _medium_fee_judge;
    try {
        _check_ring_formation();
    } finally {
        G.judge = real_judge;
    }
}


def _check_ring_formation {
    template = "Loan approved! Pay a Ksh 500 processing fee to Till {till} today.";
    first = _ingest_and_guard("+254700310001", template.format(till="660011"));
    second = _ingest_and_guard("+254700310002", template.format(till="660011"));
    lookalike = _ingest_and_guard("+254700310009", template.format(till="660099"));
    before = (root spawn GetMessage(message_id=first)).reports[0];
    assert before["risk"] == "medium" and not before["ring_id"], before;

    third = _ingest_and_guard("+254700310003", template.format(till="660011"));

    graph = (root spawn GraphView()).reports[0];
    rings = graph["rings"];
    assert len(rings) == 1, rings;
    assert rings[0]["senders"] == 3 and rings[0]["reports"] == 3, rings;
    linked = [e for e in graph["edges"] if e["kind"] == "LinkedTo"];
    assert len(linked) == 4, linked;  # 3 ring senders + the lookalike's own till
    for mid in [first, second, third] {
        v = (root spawn GetMessage(message_id=mid)).reports[0];
        assert v["ring_id"] == rings[0]["ring_id"], v;
        assert v["risk"] == "high", v;
        assert len(v["reasons"]) <= 3, v;
        assert "also reported from 2 other numbers" in " ".join(v["reasons"]), v;
    }
    other = (root spawn GetMessage(message_id=lookalike)).reports[0];
    assert other["risk"] == "medium" and not other["ring_id"], other;
}
