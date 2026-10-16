# Pesa Shield Glossary

Canonical domain vocabulary. Use these terms exactly in issues, verdicts, tests and UI copy. Implementation-free by design.

## Core concepts

- **Guard** — the walker that checks a message before the user acts on it. Produces a Verdict.
- **Recovery** — the walker that helps after a scam: builds a timeline, extracts facts, drafts a report, and waits for human approval.
- **Verdict** — Guard's typed output: risk level, scam type, at most three reasons, one action, explanations in English and Swahili, and the entities found.
- **Risk** — `low`, `medium` or `high`; always shown in words, never colour alone.
- **Ring** — a cluster of senders linked by a shared pay target or message template. At least three senders makes it a Ring worth escalating.
- **Pay target** — a till, paybill, phone number or link that a message asks you to pay.
- **Pattern** — a named scam archetype from the taxonomy (e.g. fee-before-loan, wrong-number reversal). Messages match Patterns.
- **Case** — Recovery's working object: the timeline, facts and drafted report for one reported loss, in draft → awaiting approval → approved (or discarded).
- **Forwarder** — an Android app that forwards each incoming SMS to Pesa Shield's ingestion webhook.
- **Redaction** — masking phone numbers and names (keeping the last 3 digits) before any text reaches the LLM or is stored. Only redacted text exists in Pesa Shield.
- **Sheng** — Kenyan Swahili-English slang mix. Synthetic messages may arrive in Sheng, but generated output (explanations, reports) is always natural Swahili, never Sheng.
- **Simulator** — the CLI command that streams the synthetic message set to the ingestion endpoint, used as the demo safety net.

## Judgement terms

- **Scam type** — the Pattern label a message is judged to match, or `none`.
- **Entity** — a phone number, till, paybill, link, amount or lender name extracted from a message; stored masked.
- **Escalation** — raising a message's risk because of graph evidence (ring membership, prior reports of the same pay target).
