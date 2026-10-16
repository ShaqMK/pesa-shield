## Problem Statement

Kenyan mobile-money users receive scam SMS daily — "wrong number, please reverse", fee-before-loan, fake prizes, fake payment confirmations — and have no fast, trustworthy way to check a message before acting on it. When money is lost, victims don't know what to do or how to report it. (Solo 24-hour JacHacks entry; this spec captures the agreed scope for the remaining ~14 hours of the event window.)

## Solution

**Pesa Shield**: an AI agent written in Jac that checks every incoming SMS for mobile-money and digital-loan scams **before the user acts**, learns scam rings through a shared graph, and — when money is lost — builds a timeline and drafts a report for the user to approve. Mobile-first web app plus CLI, one Jac backend, deployed on Jac Hammer. Every verdict is explained in plain English and natural Swahili/Sheng, with at most three reasons and one clear action. Nothing is ever sent or reported automatically; the human decides.

## User Stories

### Ingestion & Guard
1. As a mobile-money user, I want forwarded SMS messages to appear in my feed automatically, so that I never have to copy-paste to get protection.
2. As a user, I want a verdict (low/medium/high risk) on every message in plain words, so that I know at a glance what to ignore.
3. As a user, I want at most three short reasons and one clear action with each verdict, so that I can understand why a message is flagged.
4. As a user, I want my phone numbers and names replaced by tokens before anything reaches the LLM, and stored only as masked display strings, so that my private data never leaves the system in raw form.
5. As a user, I want Guard to decide which tools to call per message (entity extraction, graph lookup, lender check, similar-message lookup), so that checks are targeted rather than a fixed pipeline.
6. As a user, I want a known ring member's message to escalate in risk with evidence ("also reported from N other numbers"), so that I trust the warning.
7. As a user, I want messages that match no scam pattern judged honestly as legitimate, so that the tool doesn't cry wolf.
8. As a developer/demo operator, I want the ingestion endpoint to reject wrong or missing shared secrets, so that the public webhook can't be abused.

### Feed & Check
9. As a user, I want a live feed newest-first that updates within ~5 seconds of arrival, so that I see messages as they come.
10. As a user, I want the feed usable at 360px width and on a laptop, so that it works on any phone.
11. As a user, I want to paste a suspicious message or till number into a Check screen and get a verdict in seconds, so that I can check before paying.
12. As a user, I want risk shown as words plus colour (never colour alone), so that it's accessible.

### Rings & graph
13. As a user, I want a graph view showing senders and pay targets clustered into rings with report counts, so that organized scam campaigns become visible.
14. As a user, I want to tap a graph node to see its messages, so that I can review the evidence.

### Recovery
15. As a user who lost money, I want to tap "I lost money" on a message, so that Recovery starts building my case.
16. As a case owner, I want a typed timeline of the scam reconstructed from my messages, so that I can see what happened.
17. As a case owner, I want facts (amounts, masked numbers, pay targets, transaction codes) extracted exactly as present in the messages, so that my report is accurate.
18. As a case owner, I want a draft report addressed to recipients chosen from a configurable label list, so that I don't have to write it myself.
19. As a case owner, I want the draft to stop in "awaiting approval" and only be finalized when I approve, so that nothing is sent or reported automatically.
20. As a case owner, I want to edit or discard a draft, so that I stay in control.
21. As a case owner, I want to copy or export the final approved report text, so that I can send it to authorities myself.

### Language
22. As a Swahili-speaking user, I want verdict explanations in natural Swahili (not literal translation), so that I actually understand the warning.
23. As a user, I want one language toggle that switches verdict explanations and report drafts, so that language is a single choice.

### CLI & demo
24. As a demo operator, I want `pesashield check "<message>"` to run Guard and print the verdict, so that I can demo from a terminal.
25. As a demo operator, I want `pesashield simulate` to stream the synthetic set with delays, so that the demo works even if the phone/network fails.
26. As a demo operator, I want `pesashield graph` to print rings with counts, so that CLI demos show ring detection.
27. As a demo operator, I want `pesashield case start/show/approve` to run the full Recovery approval flow, so that the human-in-the-loop is demoable in the CLI too.
28. As a demo operator, I want idempotent `seed`/`reset` walkers with auto-seed-if-empty, so that the demo works regardless of whether Jac Hammer persists graph state across redeploys.

### Trust & safety
29. As a user, I want "snapshot, verify before use" labels on lender and reporting-channel data, so that I don't mistake placeholders for verified data.
30. As a user, I want clear disclaimers (decision aid, not legal advice; confirm channels with telco/police), so that I don't over-trust the tool.
31. As a privacy-conscious user, I want only redacted text stored and no secrets or raw messages logged, so that my data is safe by default.

## Implementation Decisions

- **Language**: ≥80% Jac (jac 0.37.21). Only README, `jac.toml`, `.gitignore`, small static assets, small JSON seed/config files are non-Jac. No Python/JS/TS source files.
- **Endpoints**: every walker auto-exposed as `POST /walker/<name>` (jac-scale). Ingestion is a `:pub` walker with a shared secret field in the JSON body, checked by the walker. Feed/case walkers protected accordingly.
- **Tracer bullet first**: slice 1 is a single tracer proving the core loop end to end — a webhook POST of a message appears in the web feed, deployed on Jac Hammer. The root/auth model (guest root vs per-user JWT, where walkers attach) follows from what that tracer shows about Jac Hammer's runtime, not from assumptions.
- **Auth model**: read walkers (Feed, graph slice, case read) are `:pub` read-only. All mutating walkers (IngestMessage, seed, reset, case create/edit/approve/discard) require the shared secret in the JSON body — in particular `seed` and `reset` are secret-protected admin walkers. Wrong or missing secret is rejected.
- **Dedupe**: an incoming message with the same (sender key, template_hash) as an existing Message within a recent window is deduplicated — the existing message id is returned and Guard is not re-run.
- **Redaction contract**: redaction emits, per identifier found, (a) a **stable salted-hash key** — salted with a server-side salt, deterministic across messages — used for graph matching (Sender identity, LinkedTo, dedupe), and (b) a **masked display string** (e.g. last 3 digits) for UI and storage. The LLM sees only neutral tokens (e.g. `[PHONE_1]`, `[TILL_1]`), never masked values, never raw identifiers.
- **Idempotent seeding**: `seed` and `reset` are idempotent, and the taxonomy Pattern nodes auto-seed on first ingestion if missing — this removes the unverified assumption about Jac Hammer's per-deploy graph persistence.
- **LLM**: `openai/gpt-4o-mini` via `[byllm]` in `jac.toml` + `OPENAI_API_KEY` env var; low temperature; `def :pub` spelling; tool calling by passing plain Jac functions via `tools=[...]`. Simulator delays sized to OpenAI free-tier rate limits.
- **Verdict caching**: the cache applies only to the labelled synthetic demo set (keyed by message); cached verdicts are labelled as cached in the feed/UI so the demo is honest. Live messages — anything not in the labelled set — always hit the LLM.
- **Guard tools**: `extract_entities` (typed), `lookup_graph`, `check_lender` (against `config/lenders.json` placeholders), `similar_messages` (template hash). Guard writes edges (SentBy, Mentions, MatchesPattern) and updates LinkedTo/counts after the verdict.
- **Typed Verdict**: risk (`low|medium|high`), scam_type (taxonomy label or `none`), ≤3 reasons, one action, `explanation_en`, `explanation_sw` (natural Swahili only — input messages may be Sheng, but generated output is never Sheng), entities (kind + masked value), optional ring_id.
- **Ring rule**: a connected cluster of LinkedTo edges with ≥3 senders; escalates risk with evidence text.
- **Recovery**: gather case messages → typed timeline → typed facts → typed Report draft (recipients as config labels, `body_en`, `body_sw`) → status `awaiting_approval` → wait. On approve: `approved` and expose final text for copying. Nothing sent externally.
- **Graph model**: nodes Message, Sender, PayTarget, Pattern, Lender, Case; edges SentBy, Mentions, MatchesPattern, PartOfCase, LinkedTo. Store redacted text only.
- **Client**: Jac client (React-compiled), mobile-first at 360px, bottom tab bar (Feed, Check, Graph, Cases), poll Feed every 3–5s, 44px tap targets, hand-written SVG for the 10–20 node graph view. No PWA effort (jac-client has no documented manifest support).
- **CLI**: the CLI is a thin HTTP client — it calls the deployed walker endpoints (`POST /walker/<name>`) over HTTP with a configurable base URL (env var or flag), so CLI and web demonstrably share one backend. Launcher runs via `jac run --entry <command>`; command logic stays in Jac. Commands: check, simulate, graph, case start/show/approve, `--lang sw`.
- **Config**: `config/lenders.json` and `config/report_channels.json` with clearly marked placeholders (no invented real lender names/short codes).
- **Taxonomy**: 8 seeded Patterns (wrong_number_reversal, fee_before_loan, fake_prize_promo, fake_confirmation, impersonation, fake_job_or_visa_fee, sim_swap_otp_request, legit_transaction/legit_notice). Synthetic set: ~40 messages (≈24 scam / 16 legit) in English/Swahili/Sheng, fictional numbers only, including 3 messages sharing one pay target across different senders (the demo ring).
- **Working agreements**: `jac check` + run after every change; commit/push after every demoable slice; maintain `docs/jac-features.md` (feature usage + 0.34→0.37 differences); keep an API contract in-repo; **first gate: hello-world deployed on Jac Hammer with env vars (OPENAI_API_KEY etc.) working**; feature freeze ~11:00–12:00 EAT, submit by 14:30 EAT.

## Testing Decisions

- **Single seam**: all tests go through walkers. `jac test` blocks (in `.test.jac` annex files) spawn walkers against a fresh graph root and assert on the typed reports. No unit-testing of internals.
- **Eval**: the labelled synthetic set is executed via `jac test` — one case per message asserting `expected_risk` and `expected_scam_type` (cached verdicts keep it fast/deterministic).
- **Test cap**: exactly three integration checks plus one eval. The integration checks: (1) ingestion with wrong/missing secret is rejected; (2) a 3-message ring from different senders produces LinkedTo edges and escalation; (3) Recovery stops in `awaiting_approval` and only finalizes on approve. The eval is **threshold-based**, not per-message: accuracy over the labelled synthetic set must clear an agreed threshold (target ≥ 85%). No other tests — time is the constraint.
- **Manual acceptance**: feed updates within ~5s at 360px; forwarder app posts through to the feed live; CLI and web hit the same walkers.

## Out of Scope

- X1 M-Pesa statement upload/reconstruction; X2 push notifications or WhatsApp/Telegram bots; X3 "this was legit" feedback button; X4 standalone `eval` CLI command (eval lives in `jac test` instead).
- PWA installability, native apps, anything sent externally from Recovery.
- Production concerns: real lender/channel data, telco/regulator integrations, on-device SMS filtering (pitch material only).

## Further Notes

- Everything here was decided in the grill session; the Jac-specific facts were verified against the 0.37 docs (walker endpoint exposure, `:pub`/JWT auth, `[byllm]` config, `jac test` semantics, linguist recognition of Jac). Unverified: Jac Hammer per-deploy persistence — hedged via idempotent seeding.
- Demo plan: loan-fee SMS arrives → feed flags it with reasons + Swahili toggle → `simulate` forms a ring in the graph view → "I lost money" produces an approved report → close on Jac features and Jac Hammer.
- Sub-slices will be broken out as tickets by `/to-tickets` next.
