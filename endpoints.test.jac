"""Integration checks for the T1 tracer (spawn walkers on root).

Per the spec's testing decisions, tests go through walkers and assert on
reports; no internals are tested directly.
"""

test "webhook rejects wrong or missing secret" {
    try {
        w = root spawn IngestMessage(secret="nope", sender="+254700111222", text="hi");
        assert False, ("wrong secret must raise", w.reports);
    } except RuntimeError as e {
        assert "forbidden" in str(e), ("wrong secret rejection message", str(e));
    }
    try {
        w2 = root spawn IngestMessage(sender="+254700111222", text="hi");
        assert False, ("missing secret must raise", w2.reports);
    } except RuntimeError as e {
        assert "forbidden" in str(e), ("missing secret rejection message", str(e));
    }
}

test "webhook creates message and returns analysing" {
    _secret_override = "test-secret";
    w = root spawn IngestMessage(
        secret="test-secret",
        sender="+254700111222",
        text="fee before loan scam text 0700123456"
    );
    assert len(w.reports) == 1;
    assert w.reports[0]["status"] == "analysing";
    assert w.reports[0]["id"] != "";
}

test "webhook is idempotent on identical message" {
    _secret_override = "test-secret";
    a = root spawn IngestMessage(secret="test-secret", sender="+254700111222", text="dedupe me 0700123456");
    b = root spawn IngestMessage(secret="test-secret", sender="+254700111222", text="dedupe me 0700123456");
    assert a.reports[0]["id"] == b.reports[0]["id"], ("dedupe must return the existing id", a.reports, b.reports);
}

test "feed returns messages newest first with analysing status" {
    _secret_override = "test-secret";
    a = root spawn IngestMessage(secret="test-secret", sender="+254700111222", text="msg one 0700123456");
    b = root spawn IngestMessage(secret="test-secret", sender="+254700444555", text="msg two 0711555666");
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
