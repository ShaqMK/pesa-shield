"""Labelled synthetic set: scoring, the live eval, and the regression check.

    jac run --no-serve --no-takeover evals.jac live      # ONE pass against the real LLM (SPEC: Live eval)

The live eval ingests every message of data/synthetic_messages.json into a
fresh local graph (so lookup_graph sees ring evidence build up), runs Guard
against the real LLM with the cache bypassed, and writes:
  - data/live_eval.json         the accuracy figure reported in the pitch
  - config/verdict_cache.json   the verdicts, so demos and the regression
                                check replay them labelled `cached`
evals.test.jac replays the cache through the Check walker under `jac test`:
that is the regression check, and its number is never the reported accuracy.

A prediction is correct when risk medium/high <-> label scam and
low <-> legit; scam_type agreement is reported alongside.
"""

import os;
import sys;
import json;
import from time {
    sleep
}
import from datetime {
    datetime
}
import from labelled {
    cache_key,
    config_path
}

glob THRESHOLD: float = 0.85,
     _ROOT: str = os.path.dirname(os.path.abspath(__file__)),
     DATASET_PATH: str = os.path.join(_ROOT, "data", "synthetic_messages.json"),
     LIVE_EVAL_PATH: str = os.path.join(_ROOT, "data", "live_eval.json");


def load_dataset -> list[dict[str, any]] {
    with open(DATASET_PATH, encoding="utf-8") as f {
        return (json.load(f) as dict[str, any])["messages"] as list[dict[str, any]];
    }
}


def predicted_label(risk: str) -> str {
    return "scam" if risk in ["medium", "high"] else "legit";
}


def _ratio(part: int, total: float) -> float {
    return int(part / total * 10000) / 10000.0;
}


"""Score predictions against labels. Each row: id, label, scam_type,
risk, predicted_type."""
def score(rows: list[dict[str, any]]) -> dict[str, any] {
    correct = [r for r in rows if predicted_label(str(r["risk"])) == r["label"]];
    typed = [r for r in rows if r["predicted_type"] == r["scam_type"]];
    total: float = float(max(len(rows), 1));
    return {
        "n": len(rows),
        "correct": len(correct),
        "accuracy": _ratio(len(correct), total),
        "scam_type_accuracy": _ratio(len(typed), total),
        "misses": [str(r["id"]) for r in rows if r not in correct]
    };
}


def _judgement_dict(result: any) -> dict[str, any] {
    j = result.judgement;
    return {
        "risk": j.risk.value,
        "scam_type": j.scam_type.value,
        "reasons": j.reasons,
        "action": j.action,
        "explanation_en": j.explanation_en,
        "explanation_sw": j.explanation_sw,
        "pay_target_tokens": j.pay_target_tokens
    };
}


"""Keep earlier live evals: copy data/live_eval.json into
data/live_eval_history/ (named by its run time) before it is overwritten."""
def _archive_previous_run {
    if not os.path.exists(LIVE_EVAL_PATH) {
        return;
    }
    with open(LIVE_EVAL_PATH, encoding="utf-8") as f {
        previous = json.load(f) as dict[str, any];
    }
    history = os.path.join(_ROOT, "data", "live_eval_history");
    os.makedirs(history, exist_ok=True);
    name = "live_eval_" + str(previous.get("run_at", "unknown")).replace(":", "-") + ".json";
    with open(os.path.join(history, name), "w", encoding="utf-8") as f {
        json.dump(previous, f, indent=2, ensure_ascii=False);
    }
}


"""Run Guard on one message, waiting out provider rate limits (free-tier
keys allow only a few requests a minute) instead of scoring them as misses."""
def _guard_with_retry(run_guard: any, msg: any) -> any {
    wait_sec = float(os.getenv("EVAL_RATE_LIMIT_WAIT_SEC", "30"));
    for attempt in range(4) {
        try {
            return run_guard(
                msg.llm_text, msg.entities, msg.template_hash, jid(msg), "", msg.sender_kind
            );
        } except Exception as e {
            if "RateLimit" not in type(e).__name__ or attempt == 3 {
                raise e;
            }
            print(f"  rate limited - waiting {wait_sec:g}s");
            sleep(wait_sec);
        }
    }
    return None;
}


"""The one live pass. Returns a process exit code."""
def live_eval -> int {
    import from endpoints { IngestMessage, Reset }
    import from guard { GuardResult, apply_verdict, run_guard }
    import from model { Message }
    # jac.toml resolves ${OPENAI_API_KEY} when jac starts, so the key must be
    # in the environment before `jac run` (see README: "Load .env").
    if not os.environ.get("OPENAI_API_KEY") {
        print("OPENAI_API_KEY is not set - load .env into the environment first (README).");
        return 2;
    }
    # Local, in-process run: throwaway secrets unless the env provides them.
    for name in ["PESA_WEBHOOK_SECRET", "PESA_ADMIN_SECRET", "PESA_HMAC_SECRET"] {
        os.environ.setdefault(name, "live-eval-local");
    }
    os.environ["PESA_SELF_URL"] = "off";
    os.environ["PESA_INGEST_RATE_MAX"] = "100000";
    delay = float(os.getenv("EVAL_DELAY_SEC", "3"));

    root spawn Reset(secret=os.environ["PESA_ADMIN_SECRET"]);
    rows: list[dict[str, any]] = [];
    cache: dict[str, any] = {};
    dataset = load_dataset();
    for (i, m) in enumerate(dataset) {
        ingested = root spawn IngestMessage(
            secret=os.environ["PESA_WEBHOOK_SECRET"],
            sender=str(m["sender"]),
            text=str(m["text"])
        );
        msg = jobj(ingested.reports[0]["id"]) as Message;
        row = {"id": m["id"], "label": m["label"], "scam_type": m["scam_type"]};
        try {
            result = _guard_with_retry(run_guard, msg) as GuardResult;
            apply_verdict(msg, result);
            row["risk"] = result.judgement.risk.value;
            row["predicted_type"] = result.judgement.scam_type.value;
            row["tools_used"] = result.tools_used;
            cache[cache_key(str(m["text"]))] = _judgement_dict(result);
        } except Exception as e {
            row["risk"] = "error";
            row["predicted_type"] = "error";
            row["error"] = type(e).__name__;
        }
        rows.append(row);
        ok = predicted_label(str(row["risk"])) == m["label"];
        print(f"[{i + 1}/{len(dataset)}] {m['id']} {m['label']:5} -> {row['risk']:6} {'ok' if ok else 'MISS'}");
        sleep(delay);
    }
    summary = score(rows);
    report_doc = {
        "kind": "live_eval",
        "run_at": datetime.now().isoformat(timespec="seconds"),
        "model": "gpt-4o-mini via [plugins.byllm.model]",
        "threshold": THRESHOLD,
        **summary,
        "results": rows
    };
    _archive_previous_run();
    with open(LIVE_EVAL_PATH, "w", encoding="utf-8") as f {
        json.dump(report_doc, f, indent=2, ensure_ascii=False);
    }
    with open(config_path("verdict_cache.json"), "w", encoding="utf-8") as f {
        json.dump(cache, f, indent=2, ensure_ascii=False);
    }
    print(f"Live eval accuracy: {summary['accuracy']:.1%} ({summary['correct']}/{summary['n']}); scam_type: {summary['scam_type_accuracy']:.1%}");
    misses = summary["misses"] as list[str];
    print("Misses: " + (", ".join(misses) if misses else "none"));
    print(f"Wrote {LIVE_EVAL_PATH} and the verdict cache ({len(cache)} entries).");
    return 0;
}


with entry:__main__ {
    if sys.argv[1:] == ["live"] {
        sys.exit(live_eval());
    }
    print("usage: jac run --no-serve --no-takeover evals.jac live");
    sys.exit(2);
}
