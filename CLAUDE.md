# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What this repo is

Personal platform for AI-assisted workflow.
`set-up.sh` creates symlinks from `$HOME` (and `~/.config/nvim`) pointing into this repo,
so edits here take effect immediately for the running shell (after re-sourcing the relevant file).

## Common commands

```bash
# Re-run the installer (idempotent — safe to re-run after any structural change)
./set-up.sh
```

`pre-commit` is configured in `.pre-commit-config.yaml` with two hooks:
- **tartufo** — secret scanning on every commit.
- **shell-cmd-on-change** — automatically re-runs `set-up.sh` on `post-merge` if tracked files changed.

## Shell version

All shell code targets **Bash 5.1+**. Features unavailable in older Bash (e.g. `mapfile`, `compgen -V`, extended globs, `@(...)` patterns) are fair game.

## Shell init architecture

`dotfiles/.bashrc` is the entry point. It sets `$KXUE43_SUBSTANCE_DIR` first, then sources `lib/it-shell.sh` and immediately calls `kxue43::bash_init` (which sets up PATH, fnm, completion, and man pager). A `trap … RETURN` is armed to fire `kxue43::bash_post_init` once `dotfiles/.bashrc` finishes returning; that function resolves the current environment prefix (via `hostname`) and sources the matching `profile/<prefix>.bashrc`. After the trap, `dotfiles/.bashrc` sources the remaining interactive lib files: `lib/aliases.sh`, `lib/commands.sh`, `lib/cplan.sh`, and `lib/acmd.sh`.

All module files guard against double-sourcing via a `_kxue43_module_set_<name>` env var at the top.

`$KXUE43_SUBSTANCE_DIR` is the canonical env var pointing to the repo root; use it instead of hard-coding the path anywhere.

## Shell utility conventions

### Double-loading guard

Every sourced `.sh` module in `lib/` must open with a guard that prevents re-sourcing:

```bash
if [[ -n "${_kxue43_module_set_<name>+x}" ]]; then
  return
fi
_kxue43_module_set_<name>=1
```

`<name>` is the module's filename stem with hyphens replaced by underscores (e.g. `it-shell.sh` → `it_shell`). The `+x` form tests for the variable being set without treating an empty value as unset.

`profile/` files do not use this guard — they are sourced for their side effects, and idempotency is provided by the guards in the lib files they source.

### Function namespacing

| Scope | Convention | Example |
|---|---|---|
| User-facing interactive commands | Plain hyphenated name | `acmd`, `subp` |
| Shared internal helpers (cross-module) | `kxue43::` prefix | `kxue43::log_info`, `kxue43::bash_post_init` |
| Module-private helpers | `_kxue43_<module>::` prefix | `_kxue43_it_shell::prompt` |

The `_kxue43_<module>::` prefix applies to all bash functions that must not leak into the global namespace — including completion handlers and their helpers in `completions/` files, not just private helpers inside sourced `.sh` modules. `<module>` is always the filename stem with hyphens replaced by underscores. Local names after `::` also use underscores (e.g. `_kxue43_keyring_aws::only_missing_arg`, not `only-missing-arg`).

Never define bare helper functions without a namespace for the interactive shell — they pollute its function namespace.

### Environment variable naming

All exported env vars use the `KXUE43_` prefix (e.g. `KXUE43_SUBSTANCE_DIR`, `KXUE43_SHELL_INIT`). Guard vars use the `_kxue43_module_set_` prefix and are intentionally not exported.

## lib/ and profile/ file rules

### lib/ files

- Must have a module-load guard.
- Declare lib-to-lib dependencies by sourcing directly, using a path relative to the file's own disk location (the `readlink -f "${BASH_SOURCE[0]}"` pattern). Never rely on load order.
- May not access env vars set by other lib functions _at source time_. `$KXUE43_SUBSTANCE_DIR` is the one exception — it is a bootstrap var set by `dotfiles/.bashrc` before any lib is sourced.
- For platform, host, and user detection, call `$(uname -s)`, `$(hostname)`, `$(whoami)` inline. Do not introduce cached `KXUE43_*` vars for these. (`KXUE43_SHELL_INIT` is a session-state flag, not a cache — do not confuse the two.)
- Non-`utils.sh` lib files are for interactive shell use only and may be sourced only by `dotfiles/.bashrc` or `profile/` files — never by scripts.

### profile/ files

- No module-load guard — idempotency comes from the guards inside the lib files they source.
- Source lib files using `$KXUE43_SUBSTANCE_DIR`-relative paths (`$KXUE43_SUBSTANCE_DIR` is guaranteed present by the time any profile file is sourced).
- May source any lib file from `lib/`.

## Adding a complex interactive shell function

When an interactive shell function is non-trivial (needs its own completion, keybindings, or private helpers), give it its own `lib/<name>.sh` module instead of putting it in `lib/commands.sh`:

1. Create `lib/<name>.sh` with the standard double-loading guard at the top.
2. Source `lib/utils.sh` using the `readlink -f "${BASH_SOURCE[0]}"` relative path pattern. If the module depends on another lib file (e.g., `lib/it-shell.sh`), source it the same way — explicit, never implicit.
3. Define the public function, any `_kxue43_<name>::` private helpers, and the bash completion function + `complete` registration inline in the file.
4. The public function's help text **must** use a quoted heredoc (`cat <<'EOF'`), never unquoted (`cat <<EOF`). The `acmd` preview system locates the help range by searching for the literal string `<<'EOF'`; an unquoted heredoc will not be detected and the preview falls back to a 5-line stub.
5. Append the function name to `_kxue43_commands_list` so it appears in `acmd -l`.
6. Add `source "$KXUE43_SUBSTANCE_DIR/lib/<name>.sh"` to `dotfiles/.bashrc` if the function is needed in all environments, or to the relevant `profile/<prefix>.bashrc` if it is env-specific.
7. Run `acmd -d` to invalidate the cache; the next `acmd -l` or `acmd -p` invocation will rebuild it.

## Adding a new script to `bin/`

Every `bin/` script must follow this standard structure (required for `acmd` preview to work):

```bash
#!/usr/bin/env bash

set -eu -o pipefail

source "$(cd "$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")" && pwd)/../lib/utils.sh"

main() {
  if (($# > 0)) && [[ $1 == "-h" ]]; then
    cat <<'EOF'
Usage: <name> [-h] ...
...
EOF

    return 0
  fi

  # implementation
}

if [[ "${BASH_SOURCE[0]}" == "$0" ]]; then
  main "$@"
fi
```

Key rules:
- Scripts may only source `lib/utils.sh` — no other lib file.
- The `-h` help block **must** use `cat <<'EOF'` (quoted). The `acmd` preview system finds the help range by matching the literal `<<'EOF'` marker; an unquoted heredoc will not be detected.
- The entry-point guard must call `main "$@"`, not bare `main`.

Steps to add a new script:

1. Create the executable in `bin/<name>` using the structure above.
2. Add a matching bash completion file in `completions/<name>`.
3. Run `./set-up.sh` — it symlinks everything in `bin/` into `~/.local/bin` automatically.
4. Run `date > .keep` and commit the result. The `shell-cmd-on-change` pre-commit hook watches `.keep`; when other clones pull this commit, their `post-merge` hook will detect the change and automatically run `./set-up.sh` to pick up the new script.
5. Run `acmd -d` to invalidate the cache; the next `acmd -l` or `acmd -p` invocation will rebuild it.

## Claude Code configuration

`.claude/CLAUDE.md`, `.claude/settings.json`, `.claude/skills/`, and `.claude/agents/` are all tracked in this repo and symlinked into `~/.claude/` by `set-up.sh`.

Skills live in `.claude/skills/<skill-name>/SKILL.md`. All skill names use the `kxue43-` prefix. Each `SKILL.md` begins with YAML front matter (`name`, `description`, `allowed-tools`, etc.) followed by the instruction body.

Agents in `.claude/agents/` are internal subagents spawned by skills — not user-invocable. Their names also use the `kxue43-` prefix.

## Working docs convention

`.working-docs/` (created by the `wdocs new` script) holds ephemeral research artifacts. It always contains `spec/` and `session/` subdirectories. Files here are intentionally not kept up-to-date after implementation — treat them as historical snapshots, not authoritative descriptions.
