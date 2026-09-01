# dotfiles

This is my dotfiles repo. All of my custom configuration is in here. I use [gnu stow](https://www.gnu.org/software/stow/) to manage these config files, hence the funky file layout. I used chezmoi for a while, but it eventually become more annoying than useful, as well as it wasn't working for a fresh install on my new laptop, so I swapped back to just stow. These are in progress as I migrate everything back, namely the install script to install all of the dotfiles.

## Personal vs. work machine

Everything tracked here is meant to be machine-agnostic (no hardcoded `/Users/<name>` paths — use `$HOME`). Anything that differs between the personal and work machines goes in one of these three places instead:

| What differs | Where it lives | Tracked? |
| --- | --- | --- |
| git identity in work repos | `git/.gitconfig-work`, pulled in by `[includeIf "gitdir:~/beta/"]` in `.gitconfig` | yes — it's scoped by directory, so it's safe on both boxes |
| shell env (Bedrock vars, work-only PATH entries) | `~/.zshrc.local`, sourced at the end of `.zshrc` if present | no — write it per machine |
| Claude Code plugins / statusline / model | `~/.claude/settings.json` is stowed from here, so keep machine-only keys out of it | shared keys only |

The git default identity is personal; work repos under `~/beta/` override it automatically. Claude Code rewrites `~/.claude/settings.json` itself when you change a setting in-app (theme, model, plugins), so `git status` in this repo is the place to catch anything machine-specific that snuck in before committing.
