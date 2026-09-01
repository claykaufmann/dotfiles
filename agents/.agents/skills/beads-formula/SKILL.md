---
name: beads-formula
description: Author, validate, and ship beads workflow formulas (.formula.toml) — the declarative templates that bd cooks into protos and pours into molecules of dependency-ordered issues. Use whenever the user wants to create, edit, debug, or extend a beads formula, add a gate/aspect/bond point to a workflow, turn a repeatable process (release checklist, review pipeline, incident runbook, feature workflow) into a reusable bd workflow, or asks why a formula's field/gate/dependency isn't taking effect.
---

# Authoring beads formulas

A **formula** is a TOML file declaring a repeatable multi-step workflow. `bd cook`
compiles it into a **proto** (template); `bd mol pour` stamps the proto into a
**molecule** — real, dependency-ordered beads that flow through `bd ready`.

```
formula (.toml)  --bd cook-->  proto (template)  --bd mol pour-->  molecule (real beads)
                                                 --bd mol wisp-->  wisp (ephemeral beads)
```

Use a formula when the same shape of work recurs. One-off work needs only
`bd create` + `bd dep add`.

## Where formulas live in this dotfiles setup

Write formulas to **`~/dotfiles/beads/.beads/formulas/<name>.formula.toml`**.

`~/.beads/formulas` is a stow symlink to that directory, so a file saved there is
immediately live on the user-level search path — no install step, and it is
version-controlled. Confirm with `bd formula list`.

Full search order (earlier shadows later):

1. `<resolved-beads-dir>/formulas/` — active project
2. `<checkout-root>/.beads/formulas/` — repo-local
3. `~/.beads/formulas/` — user-level (**the stowed dotfiles dir**)
4. `$GT_ROOT/.beads/formulas/` — shared workspace root, if `GT_ROOT` is set

Formula-scoped work: a formula only needs to be repo-local when it encodes
project-specific commands. Anything reusable across projects belongs in dotfiles.

## The authoring loop

Never write a formula and call it done — **unknown TOML keys are dropped
silently**, so a typo'd field vanishes without error. Always run this loop:

```bash
# 1. Parse check: does bd see what you wrote?
bd cook ~/dotfiles/beads/.beads/formulas/my-flow.formula.toml | jq .

# 2. Confirm every field you wrote survived — especially gates and needs
bd formula show my-flow --json | jq '.steps[] | {id, needs, gate}'

# 3. Resolution check: variables substitute, no missing vars, step count right
bd mol pour my-flow --var key=value --dry-run

# 4. Real pour into a throwaway workspace before trusting it
bd mol pour my-flow --var key=value
bd mol show <root-id>
bd ready --mol <root-id>
```

Step 2 is the one that catches real bugs. If a field you wrote is absent from the
JSON, `bd` does not support it — see the dropped-fields table below.

## Schema reference

Everything below is **verified against `bd` 1.2.2**. Fields marked ✗ parse without
error but are discarded.

### Top level

```toml
formula     = "my-flow"        # required; must match the filename stem
description = "One line: what this workflow accomplishes."
version     = 1                # bump when you change step structure
type        = "workflow"       # workflow | aspect | expansion | convoy
phase       = "liquid"         # liquid (default, persistent) | vapor (ephemeral)
extends     = ["base-flow"]    # ARRAY, not a string — a bare string is a parse error
```

- `phase = "vapor"` makes `bd mol pour` print a warning steering you to
  `bd mol wisp`. Use vapor for operational runs with no audit value (patrols,
  diagnostics, release runs); liquid for anything worth referencing later.
- `extends` merges the parent's steps first, then this formula's. Step ids must
  not collide.
- ✗ A top-level `labels` key is dropped. Put labels on individual steps.

### Variables

```toml
[vars.feature]
description = "Short kebab-case slug (e.g. dark-mode)"
required    = true
pattern     = "^[a-z0-9][a-z0-9-]*$"   # documentation only — NOT enforced at pour

[vars.environment]
description = "Target environment"
default     = "staging"
enum        = ["staging", "production"]  # documentation only — NOT enforced at pour
```

- `required = true` **is** enforced: pour fails with `missing required variables`.
- `pattern` and `enum` are parsed and shown by `bd formula show` but **not
  validated at pour time in 1.2.2** — an invalid value is accepted silently. Treat
  them as documentation for the human, and restate the constraint in the
  `description` so the value is right on the first try.
- Any `{{name}}` appearing anywhere in the formula is **implicitly required**, even
  with no `[vars.name]` block. A typo'd placeholder therefore surfaces as
  `missing required variables: <typo>` at pour — cheap, but declare every variable
  explicitly so `bd formula show` documents it.
- Substitution applies to `title`, `description`, `labels`, and gate `id`/`await_id`.

### Steps

```toml
[[steps]]
id          = "design"                    # required; stable, referenced by needs
title       = "Design {{feature}}"        # required
type        = "task"                      # task (default) | bug | feature | epic | chore
priority    = 1                           # 0-4 integer; defaults to 2
labels      = ["my-flow", "phase:design"]
assignee    = "agent-name"
needs       = ["spec", "survey"]          # blocking deps on other step ids
description = """
Multi-line agent instructions.
"""
notes       = "Supplementary context."
```

**Verified accepted:** `id`, `title`, `type`, `description`, `notes`, `needs`,
`depends_on`, `waits_for`, `labels`, `priority`, `assignee`, `gate`.

**Verified dropped (✗ silently ignored):** `acceptance`, `acceptance_criteria`,
`design`, `estimate`, `optional`, `parallel`, `ref`, and any other key.

Consequences worth internalising:

- There is **no `acceptance` or `design` field** on a formula step, even though
  `bd create` has those flags. Fold acceptance criteria into `description`.
- There is **no `parallel` field**. Parallelism is the default: steps with no
  `needs` all become ready at once. Sequence is created *only* by `needs`.
- `type` accepts any string but anything outside the five valid types **falls back
  to `task`** at pour, with no warning.
- `depends_on` is an accepted alias for `needs`. Prefer `needs` — it is the
  documented spelling and reads correctly ("this step needs those").

### Gates

A gate parks a step until the world catches up. It becomes its own bead (type
`gate`) wired as a blocker of the step.

```toml
[[steps]]
id    = "ci"
title = "Wait for CI"
needs = ["pr"]

[steps.gate]
type     = "gh:run"          # human | timer | gh:run | gh:pr | bead
id       = "{{ci_workflow}}" # workflow filename, or PR number for gh:pr
await_id = "release.yml"     # alternative spelling of id
timeout  = "30m"             # Go duration: 30m, 1h, 24h — there is NO `d` unit
```

The `[steps.gate]` table must appear **immediately after** the `[[steps]]` block it
belongs to — TOML attaches it to the most recently opened array element. Move a
step and its gate travels with it only if you move both.

| type     | Waits for                            | Closed by                        |
| -------- | ------------------------------------ | -------------------------------- |
| `human`  | a person's decision                  | `bd gate resolve <id>` only      |
| `timer`  | a duration after gate creation       | `bd gate check` once elapsed     |
| `gh:run` | a GH Actions workflow to succeed     | `bd gate check` (`gh run view`)  |
| `gh:pr`  | a PR to merge                        | `bd gate check` (`gh pr view`)   |
| `bead`   | a bead in another rig to close       | manual resolve only              |

Gate fields **accepted**: `type`, `id`, `await_id`, `timeout`.
Gate field **dropped in 1.2.2**: ✗ `repo`. The docs describe a `repo` key for
cross-repo `gh:run`/`gh:pr` gates, but this build discards it — a cross-repo gate
declared in a formula silently checks the *current* repo. If you need one, create
it after pouring with `bd gate create` and set `metadata.repo` on the gate bead.

Reserve `human` gates for decisions that must never auto-close. Timer and GitHub
gates close unattended via a scheduled `bd gate check`.

### Fan-in on dynamic children

`needs` fans in on *named* steps. `waits_for` fans in on children created at
runtime:

```toml
[[steps]]
id        = "summarize"
title     = "Summarize spawned work"
waits_for = "all-children"    # or "any-children" | "children-of(step-id)"
```

**Do not put `needs` and `waits_for` on the same step.** In 1.2.2 this aborts the
entire pour with `dependency ... already exists with type "blocks" (requested
"waits-for")`. Pick one.

### Bond points

Named attachment sites so other work can be composed in without editing this
formula:

```toml
[[compose.bond_points]]
id          = "pre-merge"
description = "Attach security review, perf benchmark, or migration rehearsal"
before_step = "merge"      # or after_step = "..."
parallel    = true         # optional
```

Consumed by `bd mol bond A B`. Add bond points at the seams where teams
predictably want to inject extra work — before design, before merge, after deploy.

Only `aspects` and `bond_points` are accepted under `[compose]`. ✗ `expansions`
and anything else are dropped.

### Aspects (cross-cutting steps)

An aspect formula injects a step around every step matching a glob:

```toml
# security-scan.formula.toml
formula = "security-scan"
type    = "aspect"
version = 1

[[advice]]
target = "deploy-*"              # glob against step ids; "*" matches all

[advice.before]                  # or [advice.after]
id          = "scan-{step.id}"
title       = "Security scan before {step.title}"
description = "Scan the artifact for {step.id}."
```

Applied by the consuming formula:

```toml
[compose]
aspects = ["security-scan"]
```

`before` advice inserts a step that the target then `needs`; `after` advice
inserts a step that `needs` the target. Wiring is automatic.

Note the **single-brace** `{step.id}` / `{step.title}` interpolation in advice —
distinct from the double-brace `{{var}}` used everywhere else. Do not mix them up.

## What a poured molecule actually looks like

```
$ bd mol pour my-flow --var feature=dark-mode
✓ Poured mol: created 5 issues
  Root issue: proj-mol-tdg
  Phase: liquid (persistent in .beads/)
```

- The root bead has issue type `molecule`; steps are its children.
- IDs are **hash-based** (`proj-mol-tdg`, `proj-mol-ehm`), not the `bd-xyz.1`
  positional scheme some docs show. Never hardcode a step id in downstream tooling.
- Gates appear as separate beads titled `Gate: gh:pr 42` — and because a gate bead
  is itself open and unblocked, **it shows up in `bd ready` alongside real work**.
  Agents must not "do" a gate; a gate is closed by `bd gate resolve` or
  `bd gate check`. Say so in the description of any step you gate.
- Closing the last child does **not** close the root — sweep with
  `bd epic close-eligible`, or close it explicitly.

## House style for step descriptions

The existing `feature-greenfield` formula is the reference for tone; match it.
A formula's value is mostly in its `description` bodies — they are the prompt the
agent executes.

- Write to the agent in the imperative, not as a summary for a human reader.
- Say **why** the step exists when the ordering is the point ("cheap to change now,
  expensive after scaffold") — that is what stops an agent from skipping it.
- End every step with an explicit **`Done when:`** line stating an observable
  completion condition. This is the substitute for the missing `acceptance` field.
- Tell the agent to record durable findings as a bead comment (`bd comment`) so a
  later step can read them back after context compaction.
- Label consistently so steps are filterable: a workflow tag plus a phase tag,
  e.g. `labels = ["feature-workflow", "phase:design"]`, and `"gate"` on gated steps.
- Set `priority = 1` on the critical path and `2` on parallel-but-optional work
  (docs, changelog) so `bd ready` orders sensibly.
- Give parallel discovery steps no `needs` so they start together; join them with a
  single `needs = ["a", "b"]` on the step that consumes both.

## Designing the step graph

1. **Front-load the cheap gate.** One `human` gate after design and before
   implementation is worth more than three gates late — redirecting after design
   costs a conversation, after implementation costs a rewrite.
2. **Split at the points where work can diverge.** Discovery steps (scope, survey)
   are independent; run them in parallel and join at design.
3. **Make the interface its own step.** A scaffold step that commits to signatures
   before behaviour gives every later step a fixed target.
4. **One step per thing that can independently fail or be handed off.** Do not
   bundle "implement and test and document" — those are three ready-frontier
   entries with different failure modes.
5. **Terminal steps close the loop:** file follow-up beads for deferred work, and
   close the molecule root.

## Gotchas checklist

Run through this before declaring a formula finished:

- [ ] `bd formula show <name> --json` shows every gate, `needs`, and label you wrote
- [ ] No step has both `needs` and `waits_for` (aborts the pour)
- [ ] Every `[steps.gate]` sits directly under its own `[[steps]]` block
- [ ] `extends` is an array, not a string
- [ ] No `acceptance` / `design` / `estimate` / `parallel` fields (silently dropped)
- [ ] Every `type` is one of task / bug / feature / epic / chore
- [ ] Timeouts use `h`/`m`, never `d`
- [ ] No cross-repo `repo =` inside a gate (dropped in 1.2.2)
- [ ] `bd mol pour <name> --dry-run` resolves with no missing variables
- [ ] Step ids are stable, kebab-case, and referenced correctly by `needs`
- [ ] `phase` matches intent — `vapor` for operational runs, `liquid` for tracked work

## Command reference

```bash
bd formula list                          # all formulas on the search paths
bd formula list --type workflow          # filter by type
bd formula show <name> [--json]          # parsed view — the validation tool
bd formula convert <name>                # migrate a legacy .formula.json to TOML

bd cook <path-or-name>                   # compile → JSON on stdout (keeps {{vars}})
bd cook <name> --var k=v                 # runtime mode: substitute and resolve
bd cook <name> --dry-run                 # preview steps
bd cook <name> --persist                 # write the proto to the database (rarely needed)

bd mol pour <name> --var k=v             # instantiate persistent molecule
bd mol pour <name> --dry-run             # preview without creating
bd mol pour <name> --assignee <agent>    # assign the root at pour time
bd mol wisp <name> --var k=v             # instantiate ephemeral wisp
bd mol show <id> [--parallel]            # structure and variables
bd mol current [<id>]                    # per-step status: done/current/ready/blocked
bd mol progress <id>                     # completed/total, rate, ETA
bd mol bond A B [--type parallel|conditional] [--ref name-{{v}}]
bd mol distill <epic-id> <formula-name>  # extract a formula from an ad-hoc epic
bd mol squash <id>                       # condense to a permanent digest
bd mol burn <id>                         # delete outright, no digest

bd ready --mol <id>                      # steps executable right now
bd ready --gated                         # molecules whose gate just closed
bd gate list [--all] / show / check [--dry-run] / resolve <id>
bd gate create --type=gh:pr --blocks <id> --await-id=42
```

`bd cook` accepts a **path**; `bd mol pour` resolves by **name** from the search
paths. A formula that cooks fine but reports `not found as formula or proto ID` on
pour is simply not on a search path.

## Starting a new formula

`templates/skeleton.formula.toml` in this skill directory is a minimal, valid
starting point covering parallel discovery, a join, a human gate, and a CI gate.
Copy it, rename the `formula` key to match the filename, and replace the steps.

Read `~/dotfiles/beads/.beads/formulas/feature-greenfield.formula.toml` for a
worked example of the house style at full length.
