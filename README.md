# Pesa Shield

An AI agent, written in [Jac](https://jac-lang.org), that checks every incoming SMS for
mobile-money and digital-loan scams **before you act on it**, learns scam rings through a
shared graph, and - when money is lost - drafts a report for **you** to approve and send.
Every verdict comes in plain English and natural Swahili, with at most three reasons and one
clear action. Nothing is ever sent or reported automatically.

- **Feed** - forwarded SMS appear live; Guard (an LLM agent that picks its own tools) gives
  each a risk in words + colour, reasons, one action and a Swahili explanation.
- **Check** - paste a message, get a verdict in seconds.
- **Graph** - three or more numbers asking people to pay the same till form a **ring**; their
  earlier messages are escalated with evidence.
- **Cases** - "I lost money" builds a timeline, exact facts and a draft report that stops at
  *awaiting approval*; you approve, then copy it and send it yourself.

> Decision aid, not legal advice. Reporting channels and lender data in `config/` are
> placeholders - verify before use.

## Privacy

- Phone numbers, tills, paybills, accounts, names and links are **redacted on arrival**. Only
  an HMAC key (for matching), a masked display string (e.g. `…172`) and neutral-token text
  (`[TILL_1]`) are stored. Raw identifiers are never stored or logged.
- The LLM only ever sees neutral tokens plus whether the sender was a phone number or a sender
  ID - never a raw or masked identifier.
- Demo with **test messages only**: never forward real third-party SMS into the demo system.

## Quick start (about 10 minutes)

Pesa Shield runs on the native **`jac` 0.37.25** binary (Linux/macOS; on Windows use WSL),
the same version Jac Hammer runs:

```bash
curl -fsSL https://raw.githubusercontent.com/jaseci-labs/jaseci/main/scripts/install.sh | bash
jac --version          # 0.37.25 (the version pinned in jac.toml)
jac install            # project deps: litellm for byLLM, npm packages for the web client
```

Copy `.env.example` to `.env` in the project folder and fill in the values (`.env` is
gitignored - never put secrets in `.env.example`):

| Variable | What it is |
|---|---|
| `OPENAI_API_KEY` | OpenAI key for Guard and report drafting (gpt-4o-mini) |
| `PESA_WEBHOOK_SECRET` | Secret the SMS forwarder (and `simulate`) sends with each message |
| `PESA_ADMIN_SECRET` | Secret for `reset` / `Seed` / `GuardPending` |
| `PESA_HMAC_SECRET` | Server-side key for redaction; set once per deployment (changing it re-keys every sender) |
| `PESA_CLIENT_TOKEN` | The "access code" the web app and CLI use for Check and case actions |
| `PESA_SELF_URL` | How the server reaches itself to run Guard after ingestion. Locally the default (`http://localhost:8000`) works; **deployed, set it to the app's public URL** |

Any long random strings work for the secrets, e.g. `python3 -c "import secrets; print(secrets.token_urlsafe(24))"`.

**Load `.env` into the environment before running `jac`** - `jac.toml` reads
`${OPENAI_API_KEY}` when jac starts:

```bash
set -a; . ./.env; set +a
```

Run it (production mode; plain `jac run` is dev mode with hot reload):

```bash
jac run --no-dev
```

Open http://localhost:8000 (mobile-first; phone width works). The CLI is a script inside a
web-app project, so give it a short alias, then use it from a second terminal with the same
environment loaded:

```bash
alias pesashield='jac run --no-serve --no-takeover cli.jac'
pesashield reset                         # clean demo state + seed the 8 scam Patterns
pesashield simulate --delay 8            # stream the 44 labelled demo messages
pesashield check "Your loan is approved. Pay Ksh 500 fee to till 908172" --lang sw
pesashield graph                         # rings with sender and report counts
pesashield case start <message_id>       # then: case show / edit / approve / discard
```

The CLI is a thin HTTP client: `--base-url` (or `PESA_BASE_URL`, default
`http://localhost:8000`) points it at a deployed server, so the CLI and the web app share one
backend.

## Tests and the eval

```bash
jac check .            # type-check every module
jac x test             # integration checks, dedupe check, regression check
```

- **Integration checks** (`endpoints.test.jac`): wrong/missing credentials rejected at every
  tier; three senders sharing a till form a ring and escalate; Recovery stops at
  `awaiting_approval` and only finalizes on approve. Plus one dedupe check.
- **Live eval** - one pass of the labelled set against the real LLM, the accuracy figure for
  the pitch: `jac run --no-serve --no-takeover evals.jac live` (writes `data/live_eval.json`
  and `config/verdict_cache.json`; earlier runs are kept in `data/live_eval_history/`).
- **Regression check** (`evals.test.jac`) - replays those cached verdicts through the Check
  walker; guards against breakage and is never reported as the accuracy.

**Live eval results (gpt-4o-mini, 44 labelled messages, 2026-10-17):**

| Run | Accuracy | Scams caught | Genuine messages flagged |
|---|---|---|---|
| Live eval (first and only blind pass) | 84.1% (37/44) - below the 85% target | 28/28 | 7 - bank/M-Pesa notices, an OTP and a PIN-warning notice |
| Re-run after a prompt fix, **same 44 messages** | 95.5% (42/44) - *not* a held-out figure | 28/28 | 2 - "money received" confirmations (flagged medium) |

The prompt fix was written from the first pass's seven misses: Guard was told that "no
reports yet" is not a scam signal, that a phone number inside a confirmation is usually the
other party, and that "never share your PIN" notices are not requests. Because it was tuned on
this set, the 95.5% shows the fix worked on these messages; it does not show accuracy on new
ones. Both runs are kept in `data/` (`live_eval.json` is the re-run, `live_eval_history/`
the first pass), and the verdict cache - and so the regression check - replays the re-run.
Scam-type agreement on the re-run is 68.2%; the accuracy above is scam-vs-genuine.

## Deploy (Jac Hammer)

1. In the Hammer project, **Environment variables -> Paste .env** and paste your `.env`
   (`Get-Content .env | Set-Clipboard` on Windows, `cat .env` elsewhere). `PESA_HMAC_SECRET`
   must stay the same across redeploys.
2. Deploy `main`. Hammer installs the pinned `jac` (`jac-version = "==0.37.25"` in
   `jac.toml`) and serves the `web-app`; it should run in production mode (`jac run --no-dev`)
   - dev mode ignores the settings below.
3. Once you have the app's URL, add `PESA_SELF_URL=https://<your-app>` and redeploy, so Guard
   results arrive (otherwise messages stay *analysing*). Stuck or failed messages can be re-run
   with `POST https://<your-app>/walker/GuardPending` and body `{"secret": "<PESA_ADMIN_SECRET>"}`.
4. `pesashield reset --base-url https://<your-app>` gives a clean, seeded demo state (Patterns
   also auto-seed on the first message).

`jac.toml` locks down the built-in platform pages for a public deploy: no bootstrap
`admin`/`changeme` account (`[scale.admin] enabled = false`), no Swagger and no built-in graph
visualizer (`[serve] docs_enabled / graph_enabled = false`).

## SMS forwarder (Android, test messages only)

Use any SMS-to-webhook forwarder app on a spare Android phone and configure a rule that,
for each incoming SMS, sends:

- **Method/URL:** `POST https://<your-app>/walker/IngestMessage`
- **Header:** `Content-Type: application/json`
- **Body:** `{"secret": "<PESA_WEBHOOK_SECRET>", "sender": "<sender placeholder>", "text": "<message placeholder>"}`
  (use your app's placeholders for the sender number and the message body)

Send a test SMS to the phone: it appears in the feed as *analysing*, then with its verdict.
A wrong secret is rejected (the response's `data.error` says `forbidden`), and the same SMS
sent twice is deduplicated.

## Project layout

| File | What it holds |
|---|---|
| `main.jac` | Entry point: registers the server walkers and mounts the client app |
| `endpoints.jac`, `endpoints.test.jac` | Ingestion webhook, feed, message read, Seed / Reset; the integration and dedupe checks |
| `redaction.jac` | Redaction contract: HMAC keys, masked displays, neutral tokens |
| `guard.jac` | Guard: typed `by llm` judgement with tools, verdict cache, Check |
| `rings.jac` | Ring rules, escalation, graph read walkers |
| `recovery.jac` | Recovery: timeline, facts, typed report draft, case walkers |
| `model.jac`, `access.jac`, `labelled.jac`, `taxonomy.jac` | Graph model, credential tiers + rate limits, verdict cache, scam taxonomy |
| `frontend.jac`, `screens/`, `components/`, `services/` | The mobile-first web client (placement inferred from JSX) |
| `cli.jac` | The `check / simulate / graph / case / reset` CLI (`pesashield` alias) |
| `evals.jac`, `evals.test.jac` | Scoring and the live eval; the regression check |
| `data/synthetic_messages.json` | 44 labelled, fictional demo messages (incl. the ring triplet) |
| `config/` | Placeholder lenders, report channels, known-legit targets; the verdict cache |
| `docs/` | Spec, Jac feature notes, demo script |

See [docs/jac-features.md](docs/jac-features.md) for the Jac features used and the version
notes, and [docs/demo.md](docs/demo.md) for the 2-minute demo script.
