"""Integration checks for ingestion (spawn walkers on root).

Per the spec's testing decisions, tests go through walkers and assert on
reports; no internals are tested directly.
"""

import os;


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
