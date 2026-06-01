# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What this repo is

Personal dotfiles. `set-up.sh` creates symlinks from `$HOME` (and `~/.local/bin`) pointing into this repo, so edits here take effect immediately for the running shell (after re-sourcing the relevant file).

## Common commands

```bash
# Re-run the installer (idempotent — safe to re-run after any structural change)
./set-up.sh

# Run all pre-commit hooks against every file
pre-commit run --all-files
```

`pre-commit` is configured in `.pre-commit-config.yaml` with two hooks:
- **tartufo** — secret scanning on every commit.
- **shell-cmd-on-change** — automatically re-runs `set-up.sh` on `post-merge` if tracked files changed.

## Shell init architecture

`.bashrc` is the entry point. It sources `it-shell.sh`, `aliases.sh`, `commands.sh`, and `cplan.sh` in order, then a `trap … RETURN` fires `kxue43::bash_post_init` (defined in `it-shell.sh`), which loads the **hostname-specific** file based on `$KXUE43_HOSTNAME`.

All module files guard against double-sourcing via a `_kxue43_module_set_<name>` env var at the top.

`$KXUE43_DOTFILES_DIR` is the canonical env var pointing to the repo root; use it instead of hard-coding the path anywhere.

## Adding a new script to `bin/`

1. Create the executable in `bin/<name>`.
2. Add a matching bash completion file in `completions/<name>`.
3. Run `./set-up.sh` — it symlinks everything in `bin/` into `~/.local/bin` automatically.
4. Run `date > .keep` and commit the result. The `shell-cmd-on-change` pre-commit hook watches `.keep`; when other clones pull this commit, their `post-merge` hook will detect the change and automatically run `./set-up.sh` to pick up the new script.

## Shell utility conventions

### Double-loading guard

Every sourced `.sh` module must open with a guard that prevents re-sourcing:

```bash
if [[ -n "${_kxue43_module_set_<name>+x}" ]]; then
  return
fi
_kxue43_module_set_<name>=1
```

`<name>` is the module's filename stem with hyphens replaced by underscores (e.g. `it-shell.sh` → `it_shell`). The `+x` form tests for the variable being set without treating an empty value as unset.

### Function namespacing

| Scope | Convention | Example |
|---|---|---|
| User-facing interactive commands | Plain hyphenated name | `list-all`, `dotfp` |
| Shared internal helpers (cross-module) | `kxue43::` prefix | `kxue43::log_info`, `kxue43::bash_post_init` |
| Module-private helpers | `_kxue43_<module>::` prefix | `_kxue43_it_shell::prompt` |

Never define bare helper functions without a namespace for the interactive shell — they pollute its function namespace.

### Environment variable naming

All exported env vars use the `KXUE43_` prefix (e.g. `KXUE43_DOTFILES_DIR`, `KXUE43_HOSTNAME`, `KXUE43_PLATFORM`). Guard vars use the `_kxue43_module_set_` prefix and are intentionally not exported.

## Claude Code configuration

`.claude/CLAUDE.md`, `.claude/settings.json`, `.claude/skills/`, and `.claude/agents/` are all tracked in this repo and symlinked into `~/.claude/` by `set-up.sh`.

Skills live in `.claude/skills/<skill-name>/SKILL.md`. All skill names use the `kxue43-` prefix. Each `SKILL.md` begins with YAML front matter (`name`, `description`, `allowed-tools`, etc.) followed by the instruction body.

Agents in `.claude/agents/` are internal subagents spawned by skills — not user-invocable. Their names also use the `kxue43-` prefix.

## Working docs convention

`.working-docs/` (created by the `wdocs new` script) holds ephemeral research artifacts. It always contains `spec/` and `session/` subdirectories. Files here are intentionally not kept up-to-date after implementation — treat them as historical snapshots, not authoritative descriptions.
