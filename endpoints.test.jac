"""Integration checks (spawn walkers on root).

Per the spec's testing decisions, tests go through walkers and assert on
reports; no internals are tested directly. The only stand-ins are at the
LLM boundary: Guard's `judge` and Recovery's `draft_narrative` are replaced
by fixed answers (and restored) so no model is called.
"""

import os;
import json;
import guard as G;
import recovery as R;
import from guard {
    GuardMessage,
    Judgement,
    Risk,
    ScamType
}
import from rings {
    GraphView
}
import from recovery {
    ApproveCase,
    EditCase,
    GetCase,
    ReportDraft,
    StartCase
}


def _use_test_secrets {
    os.environ["PESA_WEBHOOK_SECRET"] = "test-webhook-secret";
    os.environ["PESA_ADMIN_SECRET"] = "test-admin-secret";
    os.environ["PESA_HMAC_SECRET"] = "test-hmac-secret";
    os.environ["PESA_SELF_URL"] = "off";
    os.environ["PESA_CLIENT_TOKEN"] = "test-client-token";
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

"""Dedupe check: the same message from the same sender, posted twice,
returns the existing message id instead of ingesting it again."""
test "dedupe returns the existing message id" {
    _use_test_secrets();
    first = root spawn IngestMessage(
        secret="test-webhook-secret", sender="+254700111222", text="dedupe me 0700123456"
    );
    again = root spawn IngestMessage(
        secret="test-webhook-secret", sender="+254700111222", text="dedupe me 0700123456"
    );
    assert again.reports[0]["id"] == first.reports[0]["id"], (first.reports, again.reports);
    assert again.reports[0]["dedupe"] == "true", again.reports;
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

    view = (root spawn GraphView()).reports[0];
    rings = view["rings"];
    assert len(rings) == 1, rings;
    assert rings[0]["senders"] == 3 and rings[0]["reports"] == 3, rings;
    linked = [e for e in view["edges"] if e["kind"] == "LinkedTo"];
    assert len(linked) == 4, linked;  # 3 ring senders + the lookalike's own till
    for mid in [first, second, third] {
        v = (root spawn GetMessage(message_id=mid)).reports[0];
        assert v["ring_id"] == rings[0]["ring_id"], v;
        assert v["risk"] == "high", v;
        assert len(v["reasons"]) <= 3, v;
        assert "also reported from 2 other numbers" in " ".join(v["reasons"] as list[str]), v;
    }
    other = (root spawn GetMessage(message_id=lookalike)).reports[0];
    assert other["risk"] == "medium" and not other["ring_id"], other;
}


def _fixed_draft(timeline: list[str], scam_type: str) -> ReportDraft {
    return ReportDraft(
        narrative_en="I was asked to pay a fee before a loan and lost the money.",
        narrative_sw="Niliombwa kulipa ada kabla ya mkopo na nikapoteza pesa."
    );
}


"""Integration check 3: Recovery drafts a case and stops at awaiting_approval;
reading or editing never finalizes it; only approve (with the client token)
does, and only then is there final text to copy."""
test "recovery stops at awaiting approval and only finalizes on approve" {
    _use_test_secrets();
    (real_judge, real_draft) = (G.judge, R.draft_narrative);
    (G.judge, R.draft_narrative) = (_medium_fee_judge, _fixed_draft);
    try {
        _check_recovery_gate();
    } finally {
        (G.judge, R.draft_narrative) = (real_judge, real_draft);
    }
}


def _check_recovery_gate {
    mid = _ingest_and_guard(
        "+254700330001",
        "QWE7RT5Y1U Loan ready! Pay Ksh 650 fee to Till 770055 now to receive Ksh 20,000."
    );
    token = "test-client-token";
    opened = (root spawn StartCase(token=token, message_id=mid)).reports[0];
    assert opened["status"] == "awaiting_approval", opened;
    assert opened["final_text_en"] == "" and opened["final_text_sw"] == "", opened;
    facts = [f["kind"] + " " + f["value"] for f in opened["facts"]];
    assert "amount Ksh 650" in facts and "transaction_code QWE7RT5Y1U" in facts, facts;
    assert [f for f in opened["facts"] if f["kind"] == "till"], facts;
    assert len(opened["timeline"]) >= 1, opened;
    with open(os.path.join("config", "report_channels.json"), encoding="utf-8") as fh {
        labels = [c["label"] for c in json.load(fh)["channels"]];
    }
    assert opened["recipients"] and all([r in labels for r in opened["recipients"]]), opened;

    cid = opened["id"];
    assert (root spawn GetCase(case_id=cid)).reports[0]["status"] == "awaiting_approval";
    edited = (root spawn EditCase(token=token, case_id=cid, body_en="My edited report.")).reports[0];
    assert edited["status"] == "awaiting_approval" and edited["final_text_en"] == "", edited;

    err = "";
    try {
        root spawn ApproveCase(token="nope", case_id=cid);
    } except RuntimeError as e {
        err = str(e);
    }
    assert "forbidden" in err, err;
    assert (root spawn GetCase(case_id=cid)).reports[0]["status"] == "awaiting_approval";

    approved = (root spawn ApproveCase(token=token, case_id=cid)).reports[0];
    assert approved["status"] == "approved", approved;
    assert "My edited report." in approved["final_text_en"], approved;
    assert approved["final_text_sw"], approved;
}
