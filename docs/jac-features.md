# Jac features used in Pesa Shield

## Jac share

Measured over the repository's files, excluding docs (`.md`), generated eval outputs
(`data/live_eval*`, `config/verdict_cache.json`) and the agent-skill/ticket folders:

| Kind | Files | Non-blank lines |
|---|---|---|
| `.jac` (server, client, tests, CLI) | 30 | 4,293 |
| `.json` (dataset, config placeholders) | 4 | 126 |
| `jac.toml`, `.env.example`, `.gitignore`, `.css` | 4 | 86 |
| **Jac share** | | **95.3%** (target ≥ 80%) |

There is no Python, JavaScript or TypeScript source; the browser app is Jac compiled to
React by the client capability built into `jac`.

## Object-spatial programming (the graph)

- **Nodes**: `Sender`, `Message`, `PayTarget`, `Pattern`, `Case` (`model.jac`), all on the
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

- Client components (placement inferred from JSX) with `has` reactive state, `useEffect` polling, `async def` handlers,
  JSX with statement slots (`{for ...}`, `{if ...}`), `lang` attributes for Swahili text.
- Routing with `Router` / `Routes` / `Route` / `Link` / `useParams` / `useNavigate` from
  `@jac/runtime`; a fixed bottom tab bar.
- A hand-written SVG graph (`<svg>`, `<line>`, `<circle>`, `<text>`) computed in Jac.
- A global stylesheet import and the `app` component in `main.jac`; client vs server
  placement is inferred, no markers.

## Language and tooling

- `obj`, `enum Name: str`, `glob`, typed `has` fields with defaults, `as` casts, typed
  braced lambdas, `with entry:__main__` for the CLI
  (`jac run --no-serve --no-takeover cli.jac <command>`).
- `.test.jac` annexes run by `jac test`; `jac check` on every change; `[scripts]` in
  `jac.toml` (`jac x test`).

## Version notes

The project targets the native **`jac` 0.37.25** binary - the toolchain Jac Hammer runs (the
spec's original pin, 0.37.21, is the same line; GitHub releases, not PyPI). Slices T2-T8 were
first built on the PyPI `jaclang` 0.16.7 line and then ported. What changed between the two,
and what we hit:

1. **Client files**: 0.16.7 needed `.cl.jac` files and a `cl { }` block in `main.jac`; 0.37
   retired both - placement is inferred from JSX/npm imports (`jac fix placement` migrates).
2. **Lambdas** are braced with parenthesised params: `lambda (m: Message) -> float { ... }`
   (0.16.7: `lambda m: Message : expr`).
3. **`++>` returns the connected node** in 0.37 (a list in 0.16.7) - we construct nodes, then
   connect them, which works on both.
4. **No `global` statement** - assigning a `glob` inside a function rebinds it.
5. **Bare generics are errors** - `dict`/`list` need type arguments (`dict[str, any]`).
6. **New keywords**: `graph` (the module became `model.jac`), plus `node`, `walker`, `to`,
   `default`, `case`, `awaiting` that already bit us.
7. **`flow` can't capture graph nodes** across the concurrency boundary - pass ids.
8. **`jac.toml`**: `entry-point` is a module name (`"main"`), kinds are `web-app` etc. (not
   `fullstack`), capabilities are top-level tables (`[byllm.model]`, `[client]`; the old
   `[plugins.*]` paths no longer parse), Python packages go in `[dependencies.pypi]`, and
   `jac install` pulls capability deps (litellm) into `.jac/venv`.
9. **CLI**: `jac start` / `jac script` are gone - `jac run` (`--no-dev` for production, plain
   is dev with HMR), `jac x <script>`; a script inside a web-app project runs with
   `jac run --no-serve --no-takeover`; `jac test -f` filters by test name.
10. **Errors on the wire**: a raising walker answers HTTP 500 with `{ok: false, error}` in 0.37
    (0.16.7 answered 200 with `data.error`); the CLI and web client handle both.
11. **Built-in platform pages**: 0.37 bootstraps an `admin`/`changeme` account and serves
    `/docs`, `/graph` (a public graph visualizer) - disabled in `jac.toml` for a public deploy,
    which only takes effect in production mode.
12. **Dev server**: 0.37 dev mode splits the app (Vite, port 8000) from the API (8001) and
    proxies walker calls; the default port is 8000.

Still true on both: the `skip`-in-a-JSX-slot pitfall (use early returns), Python string
helpers on loosely typed values in client code, the 60 s client cache on read-only walker
spawns (the app uses plain `fetch`), `${VAR}` in `jac.toml` resolved at startup (load `.env`
first), and `@schedule` walkers not sharing the `:pub` root (Guard runs via a self-POST).

## AI-agent disclosure

Built for JacHacks by a solo developer with AI coding agents. The spec, scope and every
product decision came from the developer (a recorded "grill" session and ticket breakdown).
The T1 tracer was written with Codebuff; slices T2-T8 were implemented with Claude Code
(Claude Opus) working test-first against the spec, with two-axis code reviews per slice. The
developer reviewed and approved each slice and chose how to report the live eval (both runs
are disclosed in the README). The Jac Hammer deploy, the SMS forwarder on a phone and the
demo rehearsal are done by the developer.
