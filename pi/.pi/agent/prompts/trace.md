---
description: Trace how an entity, feature, or concept links together across the data model, API, and frontend
argument-hint: "[entity-feature-or-concept]"
---

Research how **$ARGUMENTS** is modeled and wired across this codebase. The goal is to build my mental model of how pieces link together. Reply in chat only — do not write any files.

If `$ARGUMENTS` is empty, ask me what to trace before doing anything else.

## Ambiguity handling

**Ask up front, before any investigation, if the request is genuinely unclear.** Examples of good reasons to ask:
- `$ARGUMENTS` is empty or a single vague word you can't resolve.
- You can think of two or more fundamentally different interpretations of what I want (e.g. "the entity itself" vs "the creation flow" vs "the admin screen") and picking wrong would waste the whole run.
- You don't know what stack / language / framework the repo uses and a quick scan won't tell you.

Prefer one crisp question with 2–4 options over free-form. Then stop and wait.

**Do not ask mid-run.** Once you've started investigating, commit. If you discover ambiguity (e.g. two tables share the name, or the entity exists in multiple domains), pick the most likely target, **state the choice in the Summary**, and list the alternatives under Open questions. A complete answer on the wrong thread is cheaper to recover from than a paused run.

## Investigation plan

Work roughly in this order, parallelising searches where possible. Spend evidence, not speculation — every claim should point at a file path.

**1. Orient (fast)**
- Identify the domain/module that most likely owns `$ARGUMENTS`.
- Note the relevant stack: ORM / DB layer, web framework, frontend framework, any codegen (OpenAPI, GraphQL, protobuf, ORM generators).
- Don't over-invest here — two or three reads is enough.

**2. Data model**
- Find the primary table(s) / model(s) for `$ARGUMENTS`. List columns with types, nullability, and defaults.
- List foreign keys in both directions: FKs *out* (what does this reference?) and FKs *in* (what references this?).
- Enumerate related enums / value objects and where they're defined.
- Capture unique constraints, indexes, composite keys, and any soft-delete / versioning / audit columns that hint at intent.
- Note any migrations that shaped the current schema, if easy to spot.

**3. API surface**
- Find the routes/handlers/controllers that read or mutate this entity.
- For each, capture: HTTP method + path (or RPC name), input schema, output schema, and the service / repository function it calls.
- Flag any background jobs, events, queues, or webhooks produced or consumed.
- Note auth / permission checks if they're non-obvious.

**4. Frontend touchpoints**
- Find the generated or hand-written client types / SDK that mirror the API.
- Find the screens, pages, or components that display or mutate this entity.
- Note the data-fetching layer (hooks, queries, stores, actions) that loads it.
- Call out any client-side caching or derived state tied to this entity.

**5. Link map**
Finish with a compact "how it hangs together" section:
- A short text diagram showing **DB → API → frontend** for `$ARGUMENTS`.
- Cross-module / cross-package relationships (things in another domain that reference this one).
- The 1–3 most surprising or non-obvious couplings you found.

## Output format

Reply in chat with this structure:

1. **Summary** — one paragraph: what `$ARGUMENTS` is in this codebase.
2. **Data model** — bullets: tables, key columns, FKs, enums, constraints. Include `path/to/file.ext:line` references.
3. **API** — list of endpoints / handlers with request + response shape and the function they dispatch to.
4. **Frontend** — screens / components and the hook/query/store that feeds them.
5. **Link map** — the text diagram plus any surprising couplings.
6. **Open questions** — anything ambiguous, inconsistent, or worth a follow-up investigation.

## Rules of engagement

- Cite exact paths with line numbers so I can jump in (`src/foo/bar.ts:42`).
- Prefer precision over coverage. If you can't confirm something, say "not verified" rather than guessing.
- Don't rewrite or edit any code. This is a read-only investigation.
- Keep prose tight — lists and short sentences beat paragraphs.
