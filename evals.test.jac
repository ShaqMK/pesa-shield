"""The eval (SPEC: Testing Decisions): the REGRESSION CHECK.

Replays the labelled synthetic set through the Check walker. Every message
must be answered from the verdict cache written by the live eval
(`jac run evals.jac live`), so no LLM is called and this number is never
the reported accuracy - it only guards against breakage.
"""

import os;
import from guard {
    Check
}
import from labelled {
    labelled_key
}


test "regression check: cached verdicts on the labelled set clear the threshold" {
    os.environ["PESA_CLIENT_TOKEN"] = "test-client-token";
    os.environ["PESA_HMAC_SECRET"] = "test-hmac-secret";
    os.environ["PESA_CHECK_RATE_MAX"] = "100000";
    dataset = load_dataset();
    uncached = [m["id"] for m in dataset if not labelled_key(m["text"])];
    assert not uncached, (
        "no cached verdict - run `jac run evals.jac live` first", uncached
    );
    rows: list[dict] = [];
    for m in dataset {
        v = (root spawn Check(
            token="test-client-token", text=m["text"], sender=m["sender"]
        )).reports[0];
        assert v["cached"], ("regression check must not call the LLM", m["id"]);
        rows.append({
            "id": m["id"],
            "label": m["label"],
            "scam_type": m["scam_type"],
            "risk": v["risk"],
            "predicted_type": v["scam_type"]
        });
    }
    result = score(rows);
    print(f"Regression check (cached, not the live accuracy): {result}");
    assert result["accuracy"] >= THRESHOLD, result;
}
