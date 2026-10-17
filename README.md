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

Needs Python 3.12 and Node.js (jac-client installs Bun itself on first start).

```bash
pip install jaclang==0.16.7 jac-client==0.3.25 byllm==0.6.19
```

Copy `.env.example` to `.env` in the project folder and fill in the values (`.env` is
gitignored - never put secrets in `.env.example`):

| Variable | What it is |
|---|---|
| `OPENAI_API_KEY` | OpenAI key for Guard and report drafting (gpt-4o-mini) |
| `PESA_WEBHOOK_SECRET` | Secret the SMS forwarder (and `simulate`) sends with each message |
| `PESA_ADMIN_SECRET` | Secret for `Seed` / `Reset` / `GuardPending` |
| `PESA_HMAC_SECRET` | Server-side key for redaction; set once per deployment (changing it re-keys every sender) |
| `PESA_CLIENT_TOKEN` | The "access code" the web app and CLI use for Check and case actions |
| `PESA_SELF_URL` | Optional: how the server reaches itself to run Guard after ingestion (default `http://127.0.0.1:$PORT`) |

Any long random strings work for the secrets, e.g. `python -c "import secrets; print(secrets.token_urlsafe(24))"`.

**Load `.env` into the environment before running `jac`** - `jac.toml` reads
`${OPENAI_API_KEY}` when jac starts:

```bash
set -a; . ./.env; set +a
```

```powershell
Get-Content .env | ForEach-Object { if ($_ -match '^\s*([^#=\s]+)\s*=\s*(.*)$') { Set-Item "env:$($Matches[1])" $Matches[2] } }
```

Run it:

```bash
jac start main.jac
```

Open http://localhost:3000 (phone width works; it is mobile-first). Then, in a second
terminal with the same environment loaded:

```bash
jac run cli.jac reset                       # clean demo state + seed the 8 scam Patterns
jac run cli.jac simulate --delay 8          # stream the 44 labelled demo messages
jac run cli.jac check "Your loan is approved. Pay Ksh 500 fee to till 908172" --lang sw
jac run cli.jac graph                       # rings with sender and report counts
jac run cli.jac case start <message_id>     # then: case show / edit / approve / discard
```

The CLI is a thin HTTP client: `--base-url` (or `PESA_BASE_URL`) points it at a deployed
server, so the CLI and the web app share one backend.

> Local-dev note: `jac start` without jac-scale serves with a single-threaded HTTP server, and
> some browsers' speculative preconnects can stall it. If the local app stops answering,
> restart it; a deployed server is unaffected.

## Tests and the eval

```bash
jac check .            # type-check every module
jac script test        # integration checks, dedupe check, regression check
```

- **Integration checks** (`endpoints.test.jac`): wrong/missing credentials rejected at every
  tier; three senders sharing a till form a ring and escalate; Recovery stops at
  `awaiting_approval` and only finalizes on approve. Plus one dedupe check.
- **Live eval** - one pass of the labelled set against the real LLM, the accuracy figure for
  the pitch: `jac run evals.jac live` (writes `data/live_eval.json` and
  `config/verdict_cache.json`; earlier runs are kept in `data/live_eval_history/`).
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

1. Create the app on Jac Hammer from this repository.
2. Start command: `jac start main.jac --port $PORT` (the client bundle is built on start).
3. Set every variable from the table above as a deployment secret / environment variable.
   `PESA_HMAC_SECRET` must stay the same across redeploys.
4. If Guard results never arrive (messages stay *analysing*), set `PESA_SELF_URL` to the
   app's own public URL. Stuck or failed messages can be re-run with
   `POST https://<your-app>/walker/GuardPending` and body `{"secret": "<PESA_ADMIN_SECRET>"}`.
5. After each redeploy: `jac run cli.jac reset --base-url https://<your-app>` gives a clean,
   seeded demo state (Patterns also auto-seed on the first message).

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
| `graph.jac`, `access.jac`, `labelled.jac`, `taxonomy.jac` | Graph model, credential tiers + rate limits, verdict cache, scam taxonomy |
| `frontend.cl.jac`, `screens/`, `components/`, `services/` | The mobile-first web client |
| `cli.jac` | The `check / simulate / graph / case / reset` CLI |
| `evals.jac`, `evals.test.jac` | Scoring and the live eval; the regression check |
| `data/synthetic_messages.json` | 44 labelled, fictional demo messages (incl. the ring triplet) |
| `config/` | Placeholder lenders, report channels, known-legit targets; the verdict cache |
| `docs/` | Spec, Jac feature notes, demo script |

See [docs/jac-features.md](docs/jac-features.md) for the Jac features used and the version
notes, and [docs/demo.md](docs/demo.md) for the 2-minute demo script.
