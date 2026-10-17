"""pesashield CLI - a thin HTTP client over the deployed walker endpoints.

    jac run cli.jac check "<message>" [--lang sw] [--base-url URL] [--token T]
    jac run cli.jac simulate [--delay SEC] [--limit N] [--secret S] [--base-url URL]

Base URL: --base-url, else PESA_BASE_URL, else http://localhost:3000.
Client token: --token, else PESA_CLIENT_TOKEN. Webhook secret (simulate):
--secret, else PESA_WEBHOOK_SECRET. The CLI and the web UI call the same
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
    URLError
}

glob USAGE: str = """usage:
  jac run cli.jac check "<message>" [--lang en|sw] [--base-url URL] [--token T]
  jac run cli.jac simulate [--delay SEC] [--limit N] [--secret S] [--base-url URL]""",
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
        delay: float = DEFAULT_DELAY_SEC,
        limit: int = 0;
}


def parse_args(argv: list[str]) -> CliArgs {
    args = CliArgs(
        base_url=os.getenv("PESA_BASE_URL", "http://localhost:3000"),
        token=os.getenv("PESA_CLIENT_TOKEN", ""),
        secret=os.getenv("PESA_WEBHOOK_SECRET", ""),
        delay=DEFAULT_DELAY_SEC
    );
    i = 0;
    while i < len(argv) {
        a = argv[i];
        if a in ["--lang", "--base-url", "--token", "--secret", "--delay", "--limit"]
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
def call_walker(base_url: str, walker_name: str, body: dict) -> list {
    req = Request(
        base_url.rstrip("/") + "/walker/" + walker_name,
        data=json.dumps(body).encode(),
        headers={"Content-Type": "application/json"}
    );
    envelope: dict = json.loads((urlopen(req, timeout=180).read() as bytes).decode()) as dict;
    if not envelope.get("ok", False) {
        raise RuntimeError(str((envelope.get("error") or {})));
    }
    data = (envelope.get("data") or {}) as dict;
    if data.get("error") {
        raise RuntimeError(str(data["error"]));
    }
    return (data.get("reports") or []) as list;
}


def print_verdict(v: dict, lang: str) {
    risk = str(v["risk"]).upper();
    scam = str(v["scam_type"]).replace("_", " ");
    print(f"Risk: {risk}  ({scam}){'  [cached]' if v['cached'] else ''}");
    print("Reasons:");
    for r in v["reasons"] as list[str] {
        print(f"  - {r}");
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
        messages = (json.load(f) as dict)["messages"] as list[dict];
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
            r = reports[0] as dict;
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


def run(argv: list[str]) -> int {
    args = parse_args(argv);
    if args.command == "simulate" {
        return simulate(args);
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
        print_verdict(reports[0] as dict, args.lang);
        return 0;
    }
    print(USAGE);
    return 2;
}


with entry:__main__ {
    sys.exit(run(sys.argv[1:]));
}
