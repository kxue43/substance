# Add `skip-skill-ids` script to set jarvis-registry skip IDs from a `skill-lock.json`

## Background

`local.skills.skip_ids` in `~/.jarvis-registry/config.yaml` is hand-edited today (jarvis-registry-cli
`docs/getting-started.md`, "Configuration reference": `local.skills.skip_ids | hand-edit`), which means
copying 24-char hex IDs out of a `skill-lock.json` by hand. This spec adds a `bin/skip-skill-ids` script
that lists the skills in a given `skill-lock.json`, lets the user multi-select them in `fzf`, and writes
the selected IDs into `local.skills.skip_ids`, plus its completion in `completions/skip-skill-ids`.

Two jarvis-registry-cli facts shape the design:

- Skipped skills are never written to `skill-lock.json`: `partitionSkippableSkills`
  (`skills/skills.go:509`) removes them from the eligible set, and the manifest is rebuilt from the
  synced skills only (`skills/skills.go:471-472`, `succeeded := succeededOnly(...)` →
  `c.mrw.WriteManifest(succeeded, ...)`). A plain overwrite of `skip_ids` would therefore silently
  drop previously skipped IDs (which can never appear in the lock file) and un-skip them on the next
  `skills sync`. The script instead **merges**: only IDs listed in the given lock file are governed by
  the selection.
- `skill-lock.json` never sits at a project root. `destinationsForMode` (`skills/skills.go:288`)
  places it at `.claude/skills/jarvis-registry/` (claude), `.agents/skills/` (codex), or
  `.github/skills/` (copilot). The completion probes those locations as well as CWD itself.

`SkipIds` is `[]string` (`cfg/config.go:40`), so numeric-looking IDs must stay YAML strings.

---

## Changes

### 1. Create `bin/skip-skill-ids`

New executable (`chmod +x`) following the standard `bin/` structure from `CLAUDE.md` ("Adding a new
script to `bin/`"). It is a single-command script like `bin/gt`, not a subcommand dispatcher. Help is
printed only for `-h`. A missing argument is an error, matching the `CLAUDE.md` template and
`bin/gn`/`bin/gt`.

Behavior, in order:

1. **Argument check:** exactly one positional `SKILL_LOCK_FILE`, otherwise error with exit 1. It can
   be absolute or relative. A relative path resolves against CWD naturally because `jq` opens it
   as given, so no `readlink` is needed. The basename is not enforced; the JSON shape check below
   is the real validation.
2. **Lock file validation:** it must be a readable regular file, and `.skills` must be an array of
   objects with string `id` and `name`, otherwise error with exit 1. This single `jq -e` check also
   rejects invalid JSON, a missing `.skills`, and `.skills` being an object.
3. **Config existence:** `$HOME/.jarvis-registry/config.yaml` must exist, otherwise error with exit 1
   and a hint to run `jarvis-registry configure`. The script never creates it, because the CLI
   requires `registry.base_url`, which the script cannot supply. The CLI's `config.yml` fallback is
   intentionally not handled.
4. **Empty `.skills`:** print an info message and exit 0 without writing.
5. **Selection:** feed `id<TAB>name` rows to fzf:
   - `--with-nth=2` displays names only.
   - `--accept-nth=1` outputs IDs directly, so no name→ID reverse lookup is needed.
   - `--bind 'load:select-all'` preselects everything, the same pattern as `_kxue43_rw::select_projects`
     in `lib/rw.sh`.
   - An `enter` guard handles a verified fzf quirk: in `-m` mode with nothing selected, `accept`
     returns the highlighted item. Without the guard, "deselect all + Enter" would silently skip one
     skill. The guard turns zero-selection Enter into `abort` (exit 130).
   - `--with-shell 'bash -c'` pins the shell that runs the `transform` command, so the `((…))`
     arithmetic doesn't depend on `$SHELL`.
6. **fzf non-zero exit** (Esc, Ctrl-C, or the guarded zero-selection Enter): print
   `Nothing selected. <config> unchanged.` and exit 0 without writing.
7. **Merge-write with `yq -i -I4`:**
   `skip_ids = (existing skip_ids // []) − (all IDs in the lock file) + (selected IDs)`.
   - Existing IDs not in the lock file are kept in their original order, and the selected IDs are
     appended in lock-file order.
   - A deselected ID that was previously in `skip_ids` is removed.
   - IDs are passed through `strenv(...) | split("\n")`, so they are tagged `!!str`. yq then quotes
     numeric-looking IDs such as `"123456789012345678901234"` or `"600000000000000000000e12"` so they
     stay strings.
   - `-I4` preserves the file's existing 4-space indentation to keep the diff minimal.
   - Verified: other keys and comments are preserved, file mode is preserved, a symlinked config is
     not replaced by a regular file, and a missing `local`/`local.skills` is auto-created.
   - On yq failure (malformed YAML, or `skip_ids` not a sequence), yq leaves the file untouched and
     the script logs an error and exits 1.
8. **Success message:** `Wrote N skill IDs from <lock> to local.skills.skip_ids in <config>.`

```bash
#!/usr/bin/env bash

set -eu -o pipefail

source "$(cd "$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")" && pwd)/../lib/utils.sh"

main() {
  if (($# > 0)) && [[ $1 == "-h" ]]; then
    cat <<'EOF'
Usage: skip-skill-ids [-h] SKILL_LOCK_FILE

Select skills listed in a jarvis-registry-cli skill-lock.json with fzf and record their IDs under
local.skills.skip_ids in ~/.jarvis-registry/config.yaml.

All skills start selected; deselect the ones that should keep syncing. Skip IDs of skills listed in
SKILL_LOCK_FILE are replaced by the selection; all other existing skip IDs are kept. Pressing Enter
with nothing selected, Esc, or Ctrl-C leaves the config file unchanged.

ARGUMENTS:
    SKILL_LOCK_FILE   Path to a skill-lock.json file, absolute or relative to CWD

OPTIONS:
    -h                Show this help message
EOF

    return 0
  fi

  if (($# != 1)); then
    kxue43::log_error "skip-skill-ids requires exactly one argument SKILL_LOCK_FILE."

    return 1
  fi

  local lock_file="$1"
  if [[ ! -f "$lock_file" || ! -r "$lock_file" ]]; then
    kxue43::log_error "$lock_file is not a readable file."

    return 1
  fi

  if ! jq -e '.skills | type == "array" and all(.[]; (.id | type == "string") and (.name | type == "string"))' "$lock_file" &>/dev/null; then
    kxue43::log_error "$lock_file is not a skill-lock.json file: .skills must be an array of objects with string id and name."

    return 1
  fi

  local config_file="$HOME/.jarvis-registry/config.yaml"
  if [[ ! -f "$config_file" ]]; then
    kxue43::log_error "$config_file does not exist. Run 'jarvis-registry configure' first."

    return 1
  fi

  local rows
  rows="$(jq -r '.skills[] | [.id, .name] | @tsv' "$lock_file")"

  if [[ -z "$rows" ]]; then
    kxue43::log_info "No skills listed in $lock_file. $config_file unchanged."

    return 0
  fi

  # With nothing selected, fzf's accept returns the highlighted item. The enter guard aborts
  # instead, so deselecting everything cannot silently skip one skill.
  local selected
  if ! selected="$(
    fzf -m --height=50% --layout=reverse --with-shell 'bash -c' \
      --delimiter='\t' --with-nth=2 --accept-nth=1 \
      --bind 'load:select-all' \
      --bind 'enter:transform:((FZF_SELECT_COUNT)) && echo accept || echo abort' <<<"$rows"
  )"; then
    kxue43::log_info "Nothing selected. $config_file unchanged."

    return 0
  fi

  local lock_ids
  lock_ids="$(jq -r '.skills[].id' "$lock_file")"

  # Skipped skills are never written to skill-lock.json, so only the IDs listed in it are
  # replaced by the selection; every other existing skip ID is kept.
  if ! LOCK_IDS="$lock_ids" IDS="$selected" yq -i -I4 \
    '.local.skills.skip_ids = (((.local.skills.skip_ids // []) - (strenv(LOCK_IDS) | split("\n"))) + (strenv(IDS) | split("\n")))' \
    "$config_file"; then
    kxue43::log_error "Failed to update local.skills.skip_ids in $config_file."

    return 1
  fi

  local -a ids
  mapfile -t ids <<<"$selected"

  kxue43::log_info "Wrote ${#ids[@]} skill IDs from $lock_file to local.skills.skip_ids in $config_file."
}

if [[ "${BASH_SOURCE[0]}" == "$0" ]]; then
  main "$@"
fi
```

The code above passes `shellcheck` (with the repo's `.shellcheckrc`) and `shfmt -i 2 -d`. It was
exercised end-to-end against a scratch `HOME`, with fzf actions injected via `FZF_DEFAULT_OPTS`. The
help heredoc is `cat <<'EOF'` (quoted), which the `acmd` preview requires (`lib/acmd.sh:39` matches
the literal `<<'EOF'`).

### 2. Create `completions/skip-skill-ids`

This follows the `completions/gt` shape and namespacing rules (`_kxue43_skip_skill_ids::` prefix). It
is auto-discovered by bash-completion via `BASH_COMPLETION_USER_DIR="$KXUE43_SUBSTANCE_DIR:…"`
(`lib/it-shell.sh:95`), so no registration elsewhere is needed.

- Only the first argument (`COMP_CWORD == 1`) completes; nothing is offered after it.
- `-` or `-h` completes to `-h`.
- Otherwise it offers whichever of these exist as regular files relative to CWD, filtered by the
  typed prefix via `compgen -V COMPREPLY -W … -- "$2"`:
  - `skill-lock.json`
  - `.claude/skills/jarvis-registry/skill-lock.json`
  - `.agents/skills/skill-lock.json`
  - `.github/skills/skill-lock.json`
- If none exist, it offers nothing. `-o bashdefault` (as in every existing completion) does not fall
  back to filename completion, so no other paths are offered.

```bash
_kxue43_skip_skill_ids::complete() {
  if ((COMP_CWORD != 1)); then
    return 0
  fi

  if [[ $2 == @(-|-h) ]]; then
    COMPREPLY=("-h")

    return 0
  fi

  # Where jarvis-registry-cli writes skill-lock.json for each skills mode, relative to a project root.
  local -a candidates=()
  local path
  for path in skill-lock.json .claude/skills/jarvis-registry/skill-lock.json .agents/skills/skill-lock.json .github/skills/skill-lock.json; do
    if [[ -f "$path" ]]; then
      candidates+=("$path")
    fi
  done

  if ((${#candidates[@]} > 0)); then
    compgen -V COMPREPLY -W "${candidates[*]}" -- "$2"
  fi

  return 0
} && complete -o bashdefault -F _kxue43_skip_skill_ids::complete skip-skill-ids

# vim: set ft=bash :
```

### 3. Bump `.keep` and install

Per `CLAUDE.md` ("Adding a new script to `bin/`", steps 3–5):
- Run `./set-up.sh`, which symlinks `bin/skip-skill-ids` into `~/.local/bin`.
- Run `date > .keep`. The user commits it with this change so other clones' `post-merge`
  `shell-cmd-on-change` hook (`.pre-commit-config.yaml`, `-P.keep`) re-runs `set-up.sh`.
- Run `acmd -d` to invalidate the command cache. `acmd` picks up the script automatically because
  `lib/acmd.sh:83` scans every executable in `bin/`.

---

## What does NOT change

- No other keys of `~/.jarvis-registry/config.yaml` are modified. Formatting may change, but the YAML
  stays equivalent, apart from `local.skills.skip_ids` and any `local`/`local.skills` created to hold
  it.
- There is no un-skip path: IDs already in `skip_ids` that are absent from the lock file are always
  preserved. Removing them stays a hand edit.
- `lib/`, `dotfiles/.bashrc`, `profile/`, and `set-up.sh` are untouched. `bin/` and `completions/` are
  discovered automatically.
- `~/.jarvis-registry/config.yml` (the CLI's fallback name) is not read or written.

---

## Acceptance Criteria

- [ ] `skip-skill-ids -h` prints the help text and exits 0. `acmd -l` lists `skip-skill-ids`, and its `acmd -p` preview shows the full help, not the 5-line stub.
- [ ] `skip-skill-ids` with no arguments, or with two arguments, prints `skip-skill-ids requires exactly one argument SKILL_LOCK_FILE.` to stderr and exits 1.
- [ ] A nonexistent path, a non-JSON file, and `{"skills":{}}` each exit 1 with an error, and `~/.jarvis-registry/config.yaml` is byte-identical (`cmp` against a pre-run copy).
- [ ] `{"skills":[]}` exits 0 with `No skills listed in …` and leaves the config byte-identical.
- [ ] With `~/.jarvis-registry/config.yaml` absent, the script exits 1 with the `Run 'jarvis-registry configure' first.` hint and does not create the file.
- [ ] fzf shows only skill names, not IDs, with every row preselected.
- [ ] From `/Users/kxue/temp/dump`, `skip-skill-ids .github/skills/skill-lock.json` resolves the relative path. Accepting the default selection appends all 20 lock-file IDs after the existing `6aa411385229dccabd728b7e` and `6aa35c3595f5817566bb326e`, which are kept. `registry.base_url` and `local.skills.mode` are unchanged.
- [ ] Deselecting a skill whose ID was already in `skip_ids` removes that ID. IDs not in the lock file are kept.
- [ ] Deselecting all rows and pressing Enter, pressing Esc, or pressing Ctrl-C each print `Nothing selected. … unchanged.`, exit 0, and leave the config byte-identical.
- [ ] A lock file containing `{"id":"123456789012345678901234","name":"n"}` produces `- "123456789012345678901234"` (quoted) in `skip_ids`, and `jarvis-registry skills show` lists every resulting ID without a config parse error.
- [ ] A comment in `config.yaml` survives a write, and the file keeps 4-space indentation.
- [ ] Completion from `/Users/kxue/temp/dump`: `skip-skill-ids <TAB>` inserts `.github/skills/skill-lock.json`; `skip-skill-ids -<TAB>` inserts `-h`; `skip-skill-ids x<TAB>` offers nothing; a second-argument `<TAB>` offers nothing.
- [ ] Completion from `/Users/kxue/temp/dump/.github/skills`: `skip-skill-ids <TAB>` inserts `skill-lock.json`. From a directory with no lock file at any probed location, `<TAB>` offers nothing, including no filename fallback.
- [ ] `shellcheck bin/skip-skill-ids completions/skip-skill-ids` and `shfmt -i 2 -d bin/skip-skill-ids completions/skip-skill-ids` report nothing.

---

## Files to Change

| File | Change |
|---|---|
| `bin/skip-skill-ids` | New executable: validate lock file and config, fzf multi-select (names shown, IDs returned, all preselected, zero-selection guard), merge-write `local.skills.skip_ids` via `yq -i -I4` |
| `completions/skip-skill-ids` | New completion: `-h`, plus whichever known `skill-lock.json` locations exist relative to CWD |
| `.keep` | `date > .keep` so other clones re-run `set-up.sh` on pull |

---

## Risk

The only file written outside the repo is `~/.jarvis-registry/config.yaml`. yq's in-place write
leaves the file untouched on any evaluation or parse error, and every abort path exits before yq
runs. The realistic regression is a future jarvis-registry-cli change to the lock-file schema or
locations, which the `jq -e` shape check turns into a clear error rather than a bad write.
