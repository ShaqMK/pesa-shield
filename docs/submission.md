# Pesa Shield — Devpost submission

**Tagline:** An AI agent in Jac that checks every mobile-money SMS for scams before you act, exposes scam rings, and drafts the police report — in Swahili too.

**Links:** [Source code](https://github.com/ShaqMK/pesa-shield) · Live app on Jac Hammer (preview link in the submission form)

---

## Inspiration

In Kenya, almost everyone has received one: *“Nimekutumia pesa kimakosa, tafadhali nirudishie”* — “I sent you money by mistake, please send it back.” Or a loan “approved” that only needs a small fee first. Mobile money carries most of the country’s everyday payments, and scam SMS ride on that trust. People have no quick, trustworthy way to check a message **before** they pay — and when money is lost, victims rarely know what to report, or to whom.

We wanted a guard that sits between the SMS and the payment, explains itself in the language people actually speak, and stays on the user’s side even after a loss — without ever acting behind their back.

## What it does

**Pesa Shield** is an AI agent that checks every incoming SMS for mobile-money and digital-loan scams *before you act*:

- **Feed** — SMS forwarded from a phone appear live. Each gets a verdict: risk in words *and* colour (low / medium / high), at most three reasons, one clear action, and an explanation in **English and natural Swahili** (never a word-for-word translation, never Sheng).
- **Check** — paste any suspicious message and get a verdict in seconds.
- **Scam rings** — when three or more different numbers ask people to pay the **same till, paybill or number**, they form a ring. Their earlier messages are escalated retroactively with evidence: *“also reported from 2 other numbers.”*
- **Recovery** — tap **“I lost money”** and Pesa Shield builds a timeline, extracts the exact facts (amounts, masked numbers, tills, transaction codes) and drafts a report in English and Swahili. It **stops at “awaiting approval”**: nothing is ever sent or reported automatically — you approve, copy it and send it yourself.
- **CLI** — `check`, `simulate`, `graph`, `case start / show / edit / approve` call the same deployed backend as the web app.

## How we used Jac / Jaseci

Everything is written in **Jac** — 94.8% of non-documentation lines, with no Python, JavaScript or TypeScript source — and it runs on the native `jac` 0.37.25 runtime, deployed on **Jac Hammer**.

- **Object-spatial programming.** Senders, messages, pay targets, scam patterns and recovery cases are **nodes** on one shared graph, joined by typed **edges** (`SentBy`, `Mentions`, `MatchesPattern`, `LinkedTo`, `PartOfCase`). Ring detection is a graph question: a `PayTarget` with \\( \geq 3 \\) distinct senders linked by medium/high-risk messages is a ring.
- **Walkers are the API.** Every `walker:pub` is automatically a REST endpoint — the SMS webhook, feed, Guard, Check, the ring view and the whole case flow — so the web app and the CLI share one backend.
- **byLLM, typed and with tools.** Guard is `def judge(message, sender_kind) -> Judgement by llm(tools=[...])`. The model returns a **typed** object (enums for risk and scam type) described entirely with `sem` strings, and it **decides per message which tools to call** — `extract_entities`, `lookup_graph`, `check_lender`, `similar_messages`. On the live deployment, a loan message naming a lender made it call `check_lender`; a family message needed no tools. Recovery’s report narrative is a second typed `by llm` call.
- **`flow`** answers the SMS webhook instantly (“analysing”) and runs Guard in the background.
- **Jac client** renders the mobile-first UI — 360px, 44px tap targets, a bottom tab bar and a hand-written SVG ring graph — from Jac components.
- **`jac check` and `jac test`.** All 26 modules type-check, and the integration checks run through the walkers: wrong credentials are rejected at every tier, a three-sender ring forms and escalates, and Recovery stops at awaiting approval until approved.

## Privacy by construction

Phone numbers, tills, accounts, names and links are redacted the moment they arrive into three things: an **HMAC key** (to match the same number across messages), a **masked display string** (`…172`) and a **neutral token** (`[TILL_1]`). The LLM only ever sees the tokens, plus whether the sender was a phone number or a registered sender ID. Raw identifiers are never stored, and API responses never echo secrets or raw text. The demo uses fictional test messages only.

## How well it works — reported honestly

We built a labelled synthetic set of 44 messages (28 scam, 16 genuine) in English, Swahili and Sheng, with fictional numbers only, including a three-sender ring.

| Run (gpt-4o-mini) | Accuracy | Scams caught |
|---|---|---|
| Blind live eval | **84.1%** (37/44) | 28/28 |
| Re-run after a prompt fix, *same 44 messages* | 95.5% (42/44) | 28/28 |

Every scam was caught both times; the misses were genuine bank and M-Pesa notices flagged as suspicious. The prompt fix was written from the first run’s misses, so 95.5% shows the fix worked on these messages — **it is not a held-out score**. Both runs are in the repository, and the `jac test` suite replays the cached verdicts as a regression check, never as the headline figure.

## Challenges we ran into

- **Two Jac toolchains.** We first built on the PyPI `jaclang` line, then found Jac Hammer runs the native `jac` 0.37 binary — with different syntax for lambdas, client files and graph connections, and new keywords (`graph` itself). We ported the whole project with Jac’s own `jac fix` migrations, verified it in a Linux environment, and confirmed it end to end on Jac Hammer.
- **Background work on a shared graph.** Writing to the graph off the request thread hung the server, and scheduled walkers ran on a different root — so Guard runs in its own request via a self-call.
- **Not crying wolf.** Real confirmations look a lot like fake ones. Telling Guard the *kind* of sender (phone number vs registered sender ID — never the value) and that “no reports yet” is not evidence made the biggest difference.
- **Safe public defaults.** The runtime’s built-in admin account, Swagger page and graph visualizer had to be switched off for a public deploy, and we found and fixed API responses echoing request secrets.

## What we learned

Jac’s graph-first model made the domain feel natural: rings, evidence and cases are just nodes and edges, and walkers turn them into an API for free. Typed `by llm` outputs turned an LLM into a component we could test, cache and reason about. And the honest number matters more than the big one.

## What’s next

On-device SMS filtering, verified lender and reporting-channel data with telcos and regulators, and a held-out evaluation set built from real, consented reports.

---

*Decision aid, not legal advice. Built with AI coding agents (disclosed in `docs/jac-features.md`); the product decisions, the deploy and the demo are the developer’s.*

## Built with

jac · jaseci · byllm · jac-client · object-spatial-programming · openai · gpt-4o-mini · litellm · react · vite · bun · postgresql · jac-hammer · hmac · svg · sms
