"""pesashield CLI - a thin HTTP client over the deployed walker endpoints.

    jac run --no-serve --no-takeover cli.jac check "<message>" [--lang sw] [--base-url URL] [--token T]
    jac run --no-serve --no-takeover cli.jac simulate [--delay SEC] [--limit N] [--secret S] [--base-url URL]
    jac run --no-serve --no-takeover cli.jac graph [--base-url URL]
    jac run --no-serve --no-takeover cli.jac case start <message_id> | show <case_id> | approve <case_id> | discard <case_id> [--lang sw]
    jac run --no-serve --no-takeover cli.jac case edit <case_id> "<new report text>" [--lang sw]
    jac run --no-serve --no-takeover cli.jac reset [--admin-secret S] [--base-url URL]

Base URL: --base-url, else PESA_BASE_URL, else http://localhost:8000.
Client token: --token, else PESA_CLIENT_TOKEN. Webhook secret (simulate):
--secret, else PESA_WEBHOOK_SECRET. Admin secret (reset): --admin-secret,
else PESA_ADMIN_SECRET. The CLI and the web UI call the same
backend; nothing here imports server code.
"""

import os;
import sys;
import json;
import from time {
    sleep
}
import from urllib.request {
    Request,
    urlopen
}
import from urllib.error {
    HTTPError,
    URLError
}

glob USAGE: str = """usage:
  jac run --no-serve --no-takeover cli.jac check "<message>" [--lang en|sw] [--base-url URL] [--token T]
  jac run --no-serve --no-takeover cli.jac simulate [--delay SEC] [--limit N] [--secret S] [--base-url URL]
  jac run --no-serve --no-takeover cli.jac graph [--base-url URL]
  jac run --no-serve --no-takeover cli.jac case start <message_id> | show <case_id> | approve <case_id> | discard <case_id> [--lang sw]
  jac run --no-serve --no-takeover cli.jac case edit <case_id> "<new report text>" [--lang sw]
  jac run --no-serve --no-takeover cli.jac reset [--admin-secret S] [--base-url URL]""",
     DATASET_PATH: str = os.path.join(
         os.path.dirname(os.path.abspath(__file__)), "data", "synthetic_messages.json"
     ),
     # Free-tier gpt-4o-mini allows only a few requests a minute and one Guard
     # run can take several (tool calls); labelled messages replay from the
     # cache, so this mostly paces the demo.
     DEFAULT_DELAY_SEC: float = 20.0;


obj CliArgs {
    has command: str = "",
        positional: list[str] = [],
        lang: str = "en",
        base_url: str = "",
        token: str = "",
        secret: str = "",
        admin_secret: str = "",
        delay: float = DEFAULT_DELAY_SEC,
        limit: int = 0;
}


def parse_args(argv: list[str]) -> CliArgs {
    args = CliArgs(
        base_url=os.getenv("PESA_BASE_URL", "http://localhost:8000"),
        token=os.getenv("PESA_CLIENT_TOKEN", ""),
        secret=os.getenv("PESA_WEBHOOK_SECRET", ""),
        admin_secret=os.getenv("PESA_ADMIN_SECRET", ""),
        delay=DEFAULT_DELAY_SEC
    );
    i = 0;
    while i < len(argv) {
        a = argv[i];
        if a in ["--lang", "--base-url", "--token", "--secret", "--admin-secret", "--delay", "--limit"]
        and i + 1 < len(argv) {
            value = argv[i + 1];
            if a == "--lang" {
                args.lang = value;
            } elif a == "--base-url" {
                args.base_url = value;
            } elif a == "--token" {
                args.token = value;
            } elif a == "--secret" {
                args.secret = value;
            } elif a == "--admin-secret" {
                args.admin_secret = value;
            } elif a == "--delay" {
                args.delay = float(value);
            } else {
                args.limit = int(value);
            }
            i += 2;
            continue;
        }
        if not args.command {
            args.command = a;
        } else {
            args.positional.append(a);
        }
        i += 1;
    }
    return args;
}


"""POST a walker and return its reports; raise with the server's reason."""
def call_walker(base_url: str, walker_name: str, body: dict[str, any]) -> list[any] {
    req = Request(
        base_url.rstrip("/") + "/walker/" + walker_name,
        data=json.dumps(body).encode(),
        headers={"Content-Type": "application/json"}
    );
    try {
        raw = (urlopen(req, timeout=180).read() as bytes).decode();
    } except HTTPError as e {
        # jac 0.37 answers a rejected call with HTTP 500 and an error envelope.
        raw = (e.read() as bytes).decode();
    }
    envelope: dict[str, any] = json.loads(raw) as dict[str, any];
    if not envelope.get("ok", False) {
        failure = (envelope.get("error") or {}) as dict[str, any];
        raise RuntimeError(str(failure.get("message") or failure));
    }
    data = (envelope.get("data") or {}) as dict[str, any];
    if data.get("error") {
        raise RuntimeError(str(data["error"]));
    }
    return (data.get("reports") or []) as list[any];
}


def print_verdict(v: dict[str, any], lang: str) {
    risk = str(v["risk"]).upper();
    scam = str(v["scam_type"]).replace("_", " ");
    print(f"Risk: {risk}  ({scam}){'  [cached]' if v['cached'] else ''}");
    reasons = v["reasons"] as list[str];
    if reasons {
        print("Reasons:");
        for r in reasons {
            print(f"  - {r}");
        }
    }
    print(f"Action: {v['action']}");
    print("");
    print(v["explanation_sw"] if lang == "sw" else v["explanation_en"]);
    tools = v["tools_used"] as list[str];
    if tools {
        print("");
        print("Guard checked: " + ", ".join(tools));
    }
}


"""Stream the synthetic set to the ingestion webhook, one message per delay."""
def simulate(args: CliArgs) -> int {
    with open(DATASET_PATH, encoding="utf-8") as f {
        messages = (json.load(f) as dict[str, any])["messages"] as list[dict[str, any]];
    }
    if args.limit > 0 {
        messages = messages[:args.limit];
    }
    print(f"Streaming {len(messages)} synthetic messages to {args.base_url} every {args.delay:g}s");
    for (i, m) in enumerate(messages) {
        try {
            reports = call_walker(
                args.base_url,
                "IngestMessage",
                {"secret": args.secret, "sender": m["sender"], "text": m["text"]}
            );
            r = reports[0] as dict[str, any];
            note = "  (duplicate)" if r.get("dedupe") else "";
            print(f"[{i + 1}/{len(messages)}] {m['id']} -> {r['status']}{note}");
        } except URLError as e {
            print(f"cannot reach {args.base_url}: {e.reason}");
            return 2;
        } except RuntimeError as e {
            print(f"[{i + 1}/{len(messages)}] {m['id']} rejected: {e}");
            if "forbidden" in str(e) or "not_configured" in str(e) {
                return 1;
            }
        }
        if i + 1 < len(messages) {
            sleep(args.delay);
        }
    }
    return 0;
}


"""Print the scam rings: pay target, linked senders, medium/high reports."""
def show_graph(args: CliArgs) -> int {
    try {
        view = call_walker(args.base_url, "GraphView", {})[0] as dict[str, any];
    } except URLError as e {
        print(f"cannot reach {args.base_url}: {e.reason}");
        return 2;
    } except RuntimeError as e {
        print(f"rejected: {e}");
        return 1;
    }
    rings = view["rings"] as list[dict[str, any]];
    if not rings {
        print("No rings yet (a ring needs 3 senders sharing one pay target).");
        return 0;
    }
    print(f"{len(rings)} ring(s):");
    for r in rings {
        print(f"  {r['ring_id']}  {r['target']}  senders: {r['senders']}  reports: {r['reports']}");
    }
    return 0;
}


def print_case(c: dict[str, any], lang: str) {
    print(f"Case {c['id']}  status: {c['status']}");
    print("");
    print("What happened:");
    for t in c["timeline"] as list[dict[str, any]] {
        print(f"  {t['at']}  {t['summary']}");
    }
    print("Facts (masked, as in the messages):");
    for f in c["facts"] as list[dict[str, any]] {
        print(f"  {f['kind']}: {f['value']}");
    }
    print("Send to (you send it): " + "; ".join(c["recipients"] as list[str]));
    print("");
    if c["status"] == "approved" {
        print("APPROVED REPORT - copy and send it yourself:");
        print(c["final_text_sw"] if lang == "sw" else c["final_text_en"]);
    } elif c["status"] == "awaiting_approval" {
        print("DRAFT - awaiting your approval (nothing has been sent):");
        print(c["body_sw"] if lang == "sw" else c["body_en"]);
        print("");
        print(f"Approve with: jac run --no-serve --no-takeover cli.jac case approve {c['id']}");
    } else {
        print("Discarded.");
    }
}


"""Recovery cases: start from a message, show, approve or discard."""
def case_command(args: CliArgs) -> int {
    actions = {
        "start": ["StartCase", "message_id"],
        "show": ["GetCase", "case_id"],
        "approve": ["ApproveCase", "case_id"],
        "discard": ["DiscardCase", "case_id"],
        "edit": ["EditCase", "case_id"]
    };
    wanted = 3 if args.positional[:1] == ["edit"] else 2;
    if len(args.positional) != wanted or args.positional[0] not in actions {
        print(USAGE);
        return 2;
    }
    (walker_name, id_field) = (actions[args.positional[0]][0], actions[args.positional[0]][1]);
    body: dict[str, any] = {id_field: args.positional[1]};
    if walker_name == "EditCase" {
        body["body_sw" if args.lang == "sw" else "body_en"] = args.positional[2];
    }
    if walker_name != "GetCase" {
        body["token"] = args.token;
    }
    try {
        reports = call_walker(args.base_url, walker_name, body);
    } except URLError as e {
        print(f"cannot reach {args.base_url}: {e.reason}");
        return 2;
    } except RuntimeError as e {
        print(f"rejected: {e}");
        return 1;
    }
    print_case(reports[0] as dict[str, any], args.lang);
    return 0;
}


"""One-command clean demo state: wipe messages, cases and rings, re-seed."""
def reset(args: CliArgs) -> int {
    try {
        r = call_walker(args.base_url, "Reset", {"secret": args.admin_secret})[0] as dict[str, any];
    } except URLError as e {
        print(f"cannot reach {args.base_url}: {e.reason}");
        return 2;
    } except RuntimeError as e {
        print(f"rejected: {e}");
        return 1;
    }
    print(f"Reset: removed {r['removed_messages']} messages; {r['patterns']} Patterns seeded.");
    return 0;
}


def run(argv: list[str]) -> int {
    args = parse_args(argv);
    if args.command == "simulate" {
        return simulate(args);
    }
    if args.command == "graph" {
        return show_graph(args);
    }
    if args.command == "case" {
        return case_command(args);
    }
    if args.command == "reset" {
        return reset(args);
    }
    if args.command == "check" and args.positional {
        try {
            reports = call_walker(
                args.base_url, "Check", {"token": args.token, "text": " ".join(args.positional)}
            );
        } except URLError as e {
            print(f"cannot reach {args.base_url}: {e.reason}");
            return 2;
        } except RuntimeError as e {
            print(f"rejected: {e}");
            return 1;
        }
        print_verdict(reports[0] as dict[str, any], args.lang);
        return 0;
    }
    print(USAGE);
    return 2;
}


with entry:__main__ {
    # Masked values use "…"; don't crash a non-UTF-8 Windows console on it.
    (sys.stdout as any).reconfigure(encoding="utf-8", errors="replace");
    sys.exit(run(sys.argv[1:]));
}
