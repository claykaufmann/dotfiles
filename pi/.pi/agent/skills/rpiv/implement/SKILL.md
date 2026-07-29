---
name: implement
description: Execute an approved implementation plan from .rpiv/artifacts/plans/ phase by phase, applying changes, committing each completed phase, and verifying each phase against its success criteria before moving on. Use when the user invokes /implement, asks to "implement this plan", or wants an existing phased plan executed. Pair with revise to update plans mid-flight and validate to confirm completion.
argument-hint: "[plan-path] [Phase N]"
allowed-tools: Read, Edit, Write, Bash(*), Glob, Grep
contract:
  produces:
    kind: side-effect
    meta:
      effect: code-mutation
  consumes:
    reads:
      plans:
        meta:
          artifactKind: plan
---

# Implement

You are tasked with implementing an approved technical plan from `.rpiv/artifacts/plans/`. These plans contain phases with specific changes and success criteria.

## Input

$ARGUMENTS

The input above is `<plan-path> [phase]`:
- First token is the plan path under `.rpiv/artifacts/plans/`.
- Anything after it (e.g. "Phase 2") names a single phase to scope to.

Rules:
- If a phase is named, implement ONLY that phase. Stop and print the closing block as soon as its success criteria pass. Do not read, edit, or check off other phases' sections.
- If no phase is named, implement every phase in the plan sequentially.
- If the input is empty or the plan path is missing/literal, ask the user for the plan path before proceeding.

## Getting Started

With a plan path in hand:
- Read the plan completely and check for any existing checkmarks (- [x])
- Read the original ticket and all files mentioned in the plan
- **Read files fully** - never use limit/offset parameters, you need complete context
- Think deeply about how the pieces fit together
- Create a todo list to track your progress
- Before touching any files, resolve **commit mode** for this run (see below)
- Start implementing if you understand what needs to be done

## Commit Mode (ask once per run)

Decide this once, before Phase 1 starts, and never ask again for the rest of the run — this is implement's one and only commit-related prompt; no per-commit confirmation follows it.

Check `git status --short` first. If the working tree already has unrelated dirty files, note that in the question's context so the user knows any phase commit will only stage files this run touches.

Use the `ask_user_question` tool. Question: "Commit automatically after each completed phase in this run?". Header: "Commit mode". Options: "Auto-commit each phase (Recommended)" (After every phase's success criteria pass, stage exactly that phase's files and create a commit automatically — you still see the commit message and a short summary every time, just without a per-phase approval prompt); "Don't commit" (Checkboxes still get updated as usual; you commit yourself later, e.g. with `/skill:commit`).

Record the answer (as `commit_mode: auto` or `commit_mode: none`) in your todo list or working notes and honor it for every phase in this run — including when the input scopes you to a single phase; still ask, the answer just governs that one phase's commit.

## Implementation Philosophy

Plans are carefully designed, but reality can be messy. Your job is to:
- Follow the plan's intent while adapting to what you find
- Implement each in-scope phase fully before starting the next
- Verify your work makes sense in the broader codebase context
- Update checkboxes in the plan as you complete sections

When things don't match the plan exactly, think about why and communicate clearly. The plan is your guide, but your judgment matters too.

If you encounter a mismatch:
- STOP and think deeply about why the plan can't be followed
- Present the issue clearly:
  ```
  Issue in Phase {N}:
  Expected: {what the plan says}
  Found: {actual situation}
  Why this matters: {explanation}

  ```

  Use the `ask_user_question` tool to resolve the mismatch. Question: "{Brief summary of the mismatch}". Header: "Mismatch". Options: "Follow the plan" (Adapt the plan's approach to the current code state); "Skip this change" (Move on without this change — it may not be needed); "Update the plan" (The plan needs to be revised before continuing).

## Verification Approach

After implementing a phase:
- Run the success criteria checks (usually `make check test` covers everything)
- Fix any issues before proceeding
- Update your progress in both the plan and your todos
- Check off completed items in the plan file itself using Edit
- If `commit_mode` is `auto`, commit the phase now — see **Committing a Phase** below — before moving to the next phase or stopping
- If the input scopes you to a single phase, stop immediately after that phase's checks pass (and its commit, if `commit_mode` is `auto`) — do not advance to other phases

Don't let verification interrupt your flow - batch it at natural stopping points.

## Committing a Phase

Only runs when `commit_mode` is `auto`. Mirrors `/skill:commit`'s message-writing logic, minus its per-commit confirmation — that confirmation already happened once, in **Commit Mode** above.

1. **Scope the diff to this phase.** Run `git status --short` and `git diff --stat` for exactly the files you touched while implementing this phase (plus the checkbox edit in the plan file itself). Never `git add -A` or `git add .` — stage each path explicitly. If the phase's changes are interleaved with pre-existing unrelated dirty files, stage only the phase's files.
2. **Write the message.** Run `git log --pretty=%s -n 20` to match the repo's existing subject-line convention (Conventional Commits, gitmoji, bare sentence-case, ticket-prefixed, etc.), imperative mood, focused on why the phase's change was made. If recent history is empty or mixed, default to imperative sentence-case with no prefix.
3. **Never add AI attribution.** No "Generated with Claude", no "Co-Authored-By" lines, no mention of the agent — write the message as if the user wrote it themselves, exactly like `/skill:commit` does.
4. **Commit.** `git add <specific paths>` then `git commit -m "<message>"`.
5. **Show the result immediately**, before moving on:
   ```
   Committed Phase {N}: {phase title}
   {short_hash} {commit subject}

   Summary: {2-4 sentence summary of what the commit contains and why}
   Files: {comma-separated list of files in this commit}
   ```
6. If `git commit` fails (pre-commit hook, nothing staged, etc.), surface the error, fix it if it's something you caused (e.g. lint), and retry once. Don't silently skip the commit or fall back to `commit_mode: none` without telling the user.

## If You Get Stuck

When something isn't working as expected:
- First, make sure you've read and understood all the relevant code
- Consider if the codebase has evolved since the plan was written
- Present the mismatch clearly and ask for guidance

Use skills sparingly - mainly for targeted debugging or exploring unfamiliar territory.

## Resuming Work

If the plan has existing checkmarks:
- Trust that completed work is done
- Pick up from the first unchecked item
- Verify previous work only if something seems off

Remember: You're implementing a solution, not just checking boxes. Keep the end goal in mind and maintain forward momentum.

## Present and Chain

When the last in-scope phase is complete, print the **completion** closing block:

```
Implementation complete:
`.rpiv/artifacts/plans/{filename}.md`

{P} phases completed, {M} files changed, {C} commits created, {T} tests passing.
Outstanding: none.

Please review the diff and let me know if anything should reopen a phase.

---

💬 Follow-up: surface code/plan mismatches inline via the `ask_user_question` flow ("Follow the plan / Skip this change / Update the plan") — that is implement's only in-skill follow-up surface. For plan-level changes run `/skill:revise <plan-path>`; for session pauses run `/skill:create-handoff`.

**Next step:** `/skill:validate .rpiv/artifacts/plans/{filename}.md` — verify the implementation against the plan's success criteria.

> 🆕 Tip: start a fresh session with `/new` first — chained skills work best with a clean context window.
```

If `commit_mode` was `none`, report `{C}` as `0 (auto-commit declined this run)` instead of a bare count.

If the run was paused mid-plan rather than completed, print the **paused** variant instead:

```
Implementation paused at Phase {N}:
`.rpiv/artifacts/plans/{filename}.md`

{P} phases completed, {M} files changed, {C} commits created, {T} tests passing.
Outstanding: {list of unchecked items, blockers}.

Please review what landed and let me know if anything needs to change before resuming.

---

💬 Follow-up: surface code/plan mismatches inline via the `ask_user_question` flow ("Follow the plan / Skip this change / Update the plan") — that is implement's only in-skill follow-up surface. For plan-level changes run `/skill:revise <plan-path>` first.

**Next step:** `/skill:create-handoff` — capture in-flight state so the next session can resume cleanly via `/skill:resume-handoff`.

> 🆕 Tip: start a fresh session with `/new` first — chained skills work best with a clean context window.
```

## Handle Follow-ups

- **Implement owns checkboxes and phase commits, not plan content.** Check off `#### Automated Verification:` items `- [ ]` → `- [x]` as each phase's checks pass, and commit each phase when `commit_mode` is `auto`. Everything else is revise's — run `/skill:revise <plan-path>`; never rewrite plan content from inside implement.
- **For plan-level changes.** Run `/skill:revise <plan-path>` first — it appends a timestamped Follow-up section to the plan and preserves history. Then resume implement at the affected phase.
- **For session pauses.** Run `/skill:create-handoff` to capture in-flight state, then `/new` and `/skill:resume-handoff` in the next session.
- **Mismatch handling stays inline.** When code reality diverges from the plan, use the inline `ask_user_question` flow ("Follow the plan / Skip this change / Update the plan") — that is implement's only follow-up surface; everything else escalates to revise or create-handoff.
