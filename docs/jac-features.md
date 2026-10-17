# Jac features used in Pesa Shield

## Jac share

Measured over the repository's files, excluding docs (`.md`), generated eval outputs
(`data/live_eval*`, `config/verdict_cache.json`) and the agent-skill/ticket folders:

| Kind | Files | Non-blank lines |
|---|---|---|
| `.jac` (server, client, tests, CLI) | 28 | 3,651 |
| `.json` (dataset, config placeholders) | 4 | 126 |
| `jac.toml`, `.env.example`, `.gitignore`, `.css` | 4 | 73 |
| **Jac share** | | **94.8%** (target ≥ 80%) |

There is no Python, JavaScript or TypeScript source; the browser app is Jac compiled to
React by jac-client.

## Object-spatial programming (the graph)

- **Nodes**: `Sender`, `Message`, `PayTarget`, `Pattern`, `Case` (`graph.jac`), all on the
  shared root that anonymous `:pub` walkers run on.
- **Typed edges with declared endpoints**: `SentBy: Message --> Sender`,
  `Mentions: Message --> PayTarget`, `MatchesPattern: Message --> Pattern`,
  `LinkedTo: Sender --> PayTarget` (carries `has count`), `PartOfCase: Message --> Case`.
- **Graph queries**: filtered traversals such as `[root -->[?:Sender, key == k]]`,
  multi-hop `[root -->[?:Sender]-->[?:Message]]`, typed hops `[t <-:Mentions:<-]`,
  edge objects `[edge s ->:LinkedTo:-> t]`, connect operators `++>` and `+>:Edge:+>`,
  cascading `del`.
- **Walkers as the API**: every `walker:pub` is a `POST /walker/<name>` endpoint -
  ingestion, feed, Guard, Check, rings, the case flow and admin `Seed`/`Reset`. Walkers use
  `report`, `disengage`, `jid`/`jobj` lookups, and raise to reject (the credential tiers in
  `access.jac`).

## byLLM (AI)

- **Typed LLM output**: `def judge(message: str, sender_kind: str) -> Judgement by llm(...)`
  returns a typed `obj` with string-backed `enum`s (`Risk`, `ScamType`); Recovery's
  `draft_narrative(...) -> ReportDraft by llm()` drafts the report narrative in English and
  natural Swahili.
- **`sem` strings** describe the function, every parameter, every output field and enum
  member to the model (e.g. "natural, everyday Kenyan Swahili ... never Sheng").
- **Tool use (ReAct)**: `tools=[extract_entities, lookup_graph, check_lender,
  similar_messages]` - Guard decides per message which tools to call; the tools used are
  recorded on each verdict and shown in the CLI.
- **Project-wide model config**: `[plugins.byllm.model]` in `jac.toml` (gpt-4o-mini,
  `${OPENAI_API_KEY}`), temperature set per call.

## Concurrency

- `flow kick_guard(id)` fires a background task after the ingestion response, which asks the
  server (over HTTP) to run Guard in its own request - "analysing" now, verdict a few seconds
  later.

## jac-client (the web app)

- `.cl.jac` components with `has` reactive state, `useEffect` polling, `async def` handlers,
  JSX with statement slots (`{for ...}`, `{if ...}`), `lang` attributes for Swahili text.
- Routing with `Router` / `Routes` / `Route` / `Link` / `useParams` / `useNavigate` from
  `@jac/runtime`; a fixed bottom tab bar.
- A hand-written SVG graph (`<svg>`, `<line>`, `<circle>`, `<text>`) computed in Jac.
- `cl { }` block and global stylesheet import in `main.jac`.

## Language and tooling

- `obj`, `enum Name: str`, `glob`, typed `has` fields with defaults, `as` casts, typed
  lambdas, `with entry:__main__` for the CLI (`jac run cli.jac <command>`).
- `.test.jac` annexes run by `jac test`; `jac check` on every change; `[scripts]` in
  `jac.toml` (`jac script test`).

## Version notes

The spec originally pinned "jac 0.37.21" and asked for 0.34 → 0.37 differences. That version
does not exist on PyPI; the project runs on **jaclang 0.16.7**, **jac-client 0.3.25** and
**byllm 0.6.19** (the newest releases). These are the differences and pitfalls we actually hit:

1. `++>` returns a **list** of the connected nodes - index `[0]`; `+>:E:+>` returns the
   target node, not the edge (read edges back with `[edge a ->:E:-> b]`).
2. Lambdas must be typed (`lambda m: Message : float(m.created_at)`).
3. Client code must live in `.cl.jac` files (or a `cl { }` block in `main.jac`), components
   must `return` their JSX, and the jac-client plugin must be installed.
4. A bare `jac test` imports `.cl.jac` modules and fails; run `jac test -f <pattern>` (and the
   `[test] filter` key is ignored by bare `jac test`).
5. A walker that raises still answers **HTTP 200 / `ok: true`**, with the reason in
   `data.error` (and its graph writes rolled back).
6. jac-client caches read-only walker calls for 60 s, which froze a polled feed - the app
   calls walkers with plain `fetch`.
7. In JSX, `skip` inside a `{if ...}` slot ends only that slot, not the component - use early
   returns.
8. Python string helpers on loosely typed values (`.lower()`, `" ".join(...)` on dict
   values) crashed in the compiled JavaScript; the built-in error screen then crashed too
   (`t.error.message`), hiding the real error.
9. `@schedule` walkers run on a different root than `:pub` walkers, and threads touching the
   graph outside a request hung the server - hence Guard runs via a self-POST.
10. `jac start` without jac-scale uses a single-threaded HTTP server; browser speculative
    preconnects can stall it in local development.
11. `jac.toml` `${VAR}` values are resolved when jac starts, so secrets must be in the
    environment before `jac start` / `jac run` (no `.env` auto-load).
12. Reserved words that bit us as identifiers: `node`, `walker`, `to`, `default`, `case`,
    `awaiting`.
13. `jac run` has no `--entry` flag; commands are `jac run cli.jac <command>`.

## AI-agent disclosure

Built for JacHacks by a solo developer with AI coding agents. The spec, scope and every
product decision came from the developer (a recorded "grill" session and ticket breakdown).
The T1 tracer was written with Codebuff; slices T2-T8 were implemented with Claude Code
(Claude Opus) working test-first against the spec, with two-axis code reviews per slice. The
developer reviewed and approved each slice and chose how to report the live eval (both runs
are disclosed in the README). The Jac Hammer deploy, the SMS forwarder on a phone and the
demo rehearsal are done by the developer.
