---
name: feature-design
description: Turn a plain-language feature description into a beads-tracked high-level design, ready for human sign-off, without writing any code. Use when the user describes a new software feature and wants it scoped/designed before building — "design a feature that does X", "spec out X before we build it", "let's think through the design of X", "/feature-design X", "high-level design for X". Pours the feature-greenfield formula, does the spec/survey/design steps live in the conversation, records rejected alternatives as linked decision beads, and stops at the design-signoff human gate. Never continues into scaffold/implement — that is separate, deliberate work.
---

# feature-design

Turns "here's a feature idea" into a beads-tracked design that a human can approve,
in one sitting — instead of requiring someone to already know to run
`bd mol pour feature-greenfield` and then separately pick up each step.

This skill is scoped to **design only**. It stops at the `design-signoff` human
gate every time, even if the user is in the room and could approve it immediately.
Approving the gate and continuing into `scaffold`/`tests`/`implement` is a separate,
deliberate action (e.g. `beads:task-agent` picking up newly-ready work after the
human runs `bd gate resolve`) — never do it as a continuation of this skill.

## 0. Check for existing work first

Before creating anything, search for a molecule that already covers this feature:

```bash
bd search "<feature keywords>"
```

If an open `feature-greenfield` molecule for this feature already exists, resume
it instead of pouring a duplicate — jump to whichever of steps 2–4 below is still
open (`bd mol current <root-id>` shows per-step status).

## 1. Turn the description into formula variables

From the user's feature description, derive:

- `feature`: a short kebab-case slug (`^[a-z0-9][a-z0-9-]*$`), e.g. `csv-export`.
- `goal`: one sentence — what a user can do after this ships that they cannot do
  today. If the user's description is already goal-shaped, restate it; if it's
  ambiguous or describes a solution rather than an outcome, ask before proceeding.
  Getting this wrong here is cheap; getting it wrong after pouring costs a redo of
  every downstream bead's title.

## 2. Pour the molecule

```bash
bd mol pour feature-greenfield --var feature=<slug> --var goal="<goal>"
```

Add `--var ci_workflow=<file>` only if you already know the project's CI workflow
filename differs from the `ci.yml` default — otherwise leave it.

Note the `Root issue: <root-id>` from the output. `bd show <root-id>` lists all 14
step beads plus their gate beads as children; `bd ready` shows `spec` and `survey`
as immediately workable (no `needs`, so both become ready together).

## 3. Work spec and survey live

Do not wait for a future session or `bd ready` polling — do this now, in this
conversation. Claim each bead (`bd update <id> --claim`) before starting it.

**spec** — restate the goal, write acceptance criteria as observable behaviors,
write explicit non-goals, note in-scope vs. deferred edge cases. Ask the user
rather than guess on anything ambiguous. Then:

```bash
bd update <spec-id> --acceptance="<criteria + non-goals>"
```

**survey** (can run before, after, or interleaved with spec — nothing blocks it) —
actually search the codebase: find the closest prior art of similar shape, the
seam this feature attaches to (router, registry, config, migration chain), the
project's naming/error-handling/test conventions, and the exact build/typecheck/
lint/test commands. Record findings as a comment (`bd comment <survey-id> "..."`).

Close both when done.

## 4. Work design live

`design` needs both `spec` and `survey` closed. Claim it, then write:

- Data model, public interface (signatures), file layout (new/modified files).
- Failure behavior for invalid input, partial failure, rollback.
- Migration/rollout: flag, config default, backfill, or none.

For **alternatives considered**: for each one worth a reader's attention, file it
as its own decision bead rather than a paragraph buried in the design bead —
this is what makes rejected approaches searchable later (`bd search "<term>"
--type decision`) instead of lost in one bead's prose:

```bash
bd create "<the alternative>" --type decision --description "## Decision
<what was chosen instead>

## Rationale
<why the chosen approach won>

## Alternatives Considered
- **<this alternative>**: <why rejected>

## Affects
- <feature> design"
bd dep add <decision-id> <design-id> --type related
```

Then record the design itself on the structured field:

```bash
bd update <design-id> --design="<the design>"
```

Close the design bead when done.

## 5. Hand off to the human gate — then stop

`design-signoff` is now ready but **do not claim or work it** — the formula
already wrote its instructions for a human reviewer. Find its gate bead:

```bash
bd gate list
```

Match the row whose description reads `Async gate for step design-signoff` — its
id is the one to hand to the human. Tell the user:

- The spec, survey, design, and any decision bead IDs, so they can review each.
- A short recap: the goal, the acceptance criteria, the design's key decisions
  and the alternatives rejected.
- The exact command to unblock the workflow once they approve:
  `bd gate resolve <gate-id>`.

Then stop. If the user asks you to also implement it, that is a new, explicit
request — not something this skill continues into on its own.
