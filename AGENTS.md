# Project Instructions for AI Agents

> Shared agent workflow policy (beads usage, stealth mode, session-completion protocol)
> lives in [AGENTS.base.md](AGENTS.base.md) — read that first. This file holds content
> specific to the **dotfiles** project only; don't duplicate the shared policy here.

## Background

This repo contains my personal dotfiles (configuration files) for my personal and work
laptop. Each top-level directory (`nvim/`, `zsh/`, `git/`, `claude/`, `pi/`, `agents/`,
`beads/`, ...) is a [GNU Stow](https://www.gnu.org/software/stow/) package: its internal
path structure mirrors `$HOME`, and `stow <package>` symlinks that structure into place
(e.g. `nvim/.config/nvim` → `~/.config/nvim`). When adding a new tool's config, create a
new top-level package folder that mirrors where it belongs under `$HOME`, don't dump
files into an existing unrelated package.

## install.sh

`install.sh` is the from-scratch bootstrap for a new machine. It is idempotent-ish but
not re-run-safe for everything (e.g. it re-clones the tmux catppuccin theme every time),
so treat it as a "new machine" script, not something to run repeatedly. Roughly, in
order:

1. Checks for Homebrew (fails fast if missing — Homebrew itself is not installed by this
   script).
2. Installs `stow`, then loops over every top-level directory (excluding `.git`) and
   runs `stow <folder>`, symlinking this repo's tracked config into `$HOME`.
3. `brew update`, then installs core CLI tools/fonts (`eza`, `nvim`, `starship`, `tmux`,
   `ripgrep`, `fzf`, etc.).
4. Clones the tmux catppuccin theme into `~/.config/tmux/plugins/catppuccin/tmux`.
5. Sources `$HOME/.zshrc`, then installs pyenv Python versions (3.10–3.13) plus a
   dedicated `neovim3` pyenv-virtualenv used only for Neovim's Python host.

The `dotfiles_dir` is hardcoded to `$HOME/dotfiles` (the author only ever clones it
there) — that's the one intentional exception to the "no hardcoded paths" rule below,
since it's describing the repo's own required clone location, not a machine-specific
value.

## Machine-agnostic paths — always use `$HOME` / `~`

Everything tracked in this repo is meant to work unmodified on both the personal and
work machine. **Never hardcode an absolute path like `/Users/<name>/...`** in a
tracked file — use `$HOME` in shell/config files and `~` where the tool supports
tilde-expansion. A hardcoded username is the single most common way this repo breaks
when stowed onto the other machine.

- Grep for `/Users/` before committing if you've added or edited a script, hook, or
  skill: `grep -rn "/Users/" --include='*.sh' --include='*.md' --include='*.py' .`
- This has already bitten this repo once: `agents/.agents/skills/trino-query/SKILL.md`
  currently hardcodes `/Users/ckaufmann/.pi/agent/skills/...` in its example command —
  that's a work-machine-only path baked into a shared skill. Treat instances like this
  as bugs to fix opportunistically, not as precedent to copy.
- Where personal/work machines genuinely need to differ, don't hardcode either value —
  use one of the three sanctioned escape hatches (see README.md's "Personal vs. work
  machine" table):
  - **Directory-scoped git identity**: `git/.gitconfig-work`, pulled in via
    `[includeIf "gitdir:~/beta/"]` in `.gitconfig`. Default identity stays personal.
  - **Per-machine shell env**: `~/.zshrc.local`, sourced at the end of `.zshrc` if
    present, and **not** tracked in this repo.
  - **Claude Code app-owned settings**: `~/.claude/settings.json` is stowed from
    `claude/.claude/settings.json`, but Claude Code rewrites it in place when you
    change theme/model/plugins in-app. Keep only shared keys in the tracked copy;
    check `git status` before committing to catch anything machine-specific that
    snuck in.

## Agents and skills layout

AI coding agent config lives in three stow packages that intentionally share content
rather than duplicate it:

- **`agents/.agents/skills/`** — the canonical, tool-agnostic home for Claude/pi
  *skills* (e.g. `trino-query`). This is the single source of truth for a skill's
  `SKILL.md` and any bundled scripts.
- **`claude/.claude/skills`** — a *symlink* to `../../agents/.agents/skills`, so
  Claude Code sees the same skills without a copy.
- **`pi/.pi/agent/skills`** — a *symlink* to `../../../agents/.agents/skills`, same
  reasoning for the `pi` agent.

**When adding or editing a skill, always work under `agents/.agents/skills/`.** Never
add a skill directly under `claude/.claude/skills/` or `pi/.pi/agent/skills/` — those
paths are symlinks; writing "into" them writes into the shared `agents/` location
anyway, but treating them as the source of truth invites drift (as happened with the
old `pi/.pi/agent/skills/rpiv/*` tree, which was tool-specific and has since been
removed in favor of the shared layout).

- `claude/.claude/` also carries Claude-Code-specific, non-skill config:
  `settings.json` (hooks, model default, permissions — kept machine-generic per the
  section above) and `hooks/` (e.g. `tmux-agent-status.sh`, which drives a tmux status
  indicator from Claude Code's `SessionStart` / `UserPromptSubmit` / `PreToolUse` /
  `PostToolUse` hooks).
- `pi/.pi/agent/` also carries pi-specific `extensions/`, `prompts/`, `settings.json`,
  and `sandbox.json` that have no Claude Code equivalent — those stay local to `pi/`.

## Beads configuration

- **`beads/.beads/formulas/`** is a stow package: it symlinks shared `bd mol pour`
  workflow *formulas* (e.g. `feature-greenfield.formula.toml`) into
  `~/.beads/formulas/`, so the same structured-workflow templates are available on
  every machine this repo is stowed onto. This is the only beads content meant to be
  tracked — it's shared tooling, not project data.
- Every other project's actual beads database (issues, Dolt data) runs in **stealth
  mode** per [AGENTS.base.md](AGENTS.base.md) — local-only, never committed. That
  applies to this repo too: this repo's own `.beads/` issue DB (as opposed to the
  `beads/.beads/formulas/` stow package above) is excluded via `.git/info/exclude`,
  not `.gitignore`.
- `.gitignore` has a deliberate re-include for this: a blanket-looking
  `.beads/` exclusion pattern (from stealth-mode `bd init`) would otherwise also
  swallow the tracked `beads/.beads/formulas/` package, since the pattern matches at
  any depth. The `!beads/.beads/` line exists specifically to un-ignore that package —
  don't remove it, and don't assume `beads/.beads/` contains a live database (it
  never should).
