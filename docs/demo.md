# Demo script (2 minutes)

Before going on stage (deployed app, environment loaded, phone on the feed):

```bash
jac run cli.jac reset --base-url https://<your-app>      # clean, seeded demo state
```

Keep `jac run cli.jac simulate` ready as the safety net if the phone or network fails.
Note: `simulate` always starts from the first message, and repeats are deduplicated - if you
used `simulate --limit 1` at 0:10, the `--limit 3` run at 0:45 adds only the other two ring
messages (the ring still forms: three senders, one till).

| Time | Show | Say |
|---|---|---|
| 0:00 | Phone on the **Feed** | "Kenyans get scam SMS daily. Pesa Shield checks every message before you act." |
| 0:10 | Send the loan-fee test SMS to the forwarder phone (or `simulate --limit 1`) | It appears as *analysing*, then **High risk** with reasons and one action. |
| 0:30 | Open it; tap **English → Kiswahili** | Natural Swahili explanation; risk in words + colour; "Guard chose its own tools". |
| 0:45 | `jac run cli.jac simulate --limit 3 --delay 5`; open **Graph** | Three numbers, one till: a **ring** forms; earlier messages escalate with "also reported from 2 other numbers". |
| 1:10 | Open a ring message → **I lost money** | Recovery builds the timeline, exact facts and a draft in English and Swahili - stopped at *awaiting approval*. |
| 1:30 | **Approve** → **Copy report** | Nothing is sent by the app; the human decides and sends it. |
| 1:45 | `jac run cli.jac check "<msg>" --lang sw` | Same backend from the CLI. |
| 1:50 | Close on `docs/jac-features.md` | Walkers as the API, typed `by llm` with tools, the shared graph, `flow`, jac-client - deployed on Jac Hammer. |

Fallbacks: if the LLM is slow, the labelled demo messages replay their cached verdicts
(labelled *cached*); if Recovery's LLM call fails, the report is drafted from a template.
