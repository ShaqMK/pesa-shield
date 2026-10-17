# Pesa Shield Glossary

Canonical domain vocabulary. Use these terms exactly in issues, verdicts, tests and UI copy. Implementation-free by design.

## Core concepts

- **Guard** — the walker that checks a message before the user acts on it. Produces a Verdict.
- **Recovery** — the walker that helps after a scam: builds a timeline, extracts facts, drafts a report, and waits for human approval.
- **Verdict** — Guard's typed output: risk level, scam type, at most three reasons, one action, explanations in English and Swahili, and the entities found.
- **Risk** — `low`, `medium` or `high`; always shown in words, never colour alone.
- **Ring** — a cluster of at least three senders linked by a shared pay target (shared templates never create ring links). A ring's count includes only medium/high messages; targets on the known-legit list are excluded. When a ring forms, member senders' earlier medium/high messages are retroactively escalated.
- **Pay target** — a till, paybill, phone number or link that a message asks you to pay.
- **Pattern** — a named scam archetype from the taxonomy (e.g. fee-before-loan, wrong-number reversal). Messages match Patterns.
- **Case** — Recovery's working object: the timeline, facts and drafted report for one reported loss, in draft → awaiting approval → approved (or discarded).
- **Forwarder** — an Android app that forwards each incoming SMS to Pesa Shield's ingestion webhook.
- **Redaction** — the step applied before storage and LLM use. Each identifier found in a message becomes three things: an HMAC key (see **Sender key**) for graph matching and dedupe, a masked display string (e.g. last 3 digits) for UI and storage, and a neutral token (e.g. `[PHONE_1]`) that is all the LLM ever sees of it (plus the **Sender kind**). Raw identifiers are never stored.
- **Sender kind** — whether a message came from a phone number or a registered sender ID (e.g. a bank or telco name). Never the value itself; Guard sees it next to the neutral-token text because real confirmations come from sender IDs, though sender IDs can be spoofed.
- **Sender key** — an HMAC of a raw identifier (phone number, name) computed with a server-side secret. Deterministic across messages, so the same sender always maps to the same graph node. Pesa Shield's internal identity for a sender or entity.
- **Template hash** — a hash of a message's normalized text. Used by Guard's similar-messages tool; never used for dedupe or ring linking.
- **Dedupe** — dropping an incoming message that matches an existing one on (sender key, byte-identical redacted text) within a recent time window; the existing message id is returned instead.
- **Webhook secret** — the credential tier the forwarder uses to post to the ingestion webhook.
- **Admin secret** — the credential tier protecting `seed`, `reset` and other admin walkers.
- **Client token** — the credential tier sent by the web UI and CLI for client-initiated actions (Check submit, case actions).
- **Analysing** — the state of a message between ingestion (which returns immediately) and the verdict's arrival in the feed.
- **Live eval** — one pass of the labelled synthetic set against the real LLM, producing the accuracy figure reported in the pitch.
- **Regression check** — the `jac test` run over the same set using cached verdicts; guards against breakage. Its result is never the reported accuracy.
- **Sheng** — Kenyan Swahili-English slang mix. Synthetic messages may arrive in Sheng, but generated output (explanations, reports) is always natural Swahili, never Sheng.
- **Sheng** — Kenyan Swahili-English slang mix. Synthetic messages may arrive in Sheng, but generated output (explanations, reports) is always natural Swahili, never Sheng.
- **Simulator** — the CLI command that streams the synthetic message set to the ingestion endpoint, used as the demo safety net.

## Judgement terms

- **Scam type** — the Pattern label a message is judged to match, or `none`.
- **Entity** — a phone number, till, paybill, link, amount or lender name extracted from a message; stored masked.
- **Escalation** — raising a message's risk because of graph evidence (ring membership, prior reports of the same pay target).
