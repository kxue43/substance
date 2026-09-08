# Add `rcliw` command for jarvis-registry-cli worktree automation

## Background

`rw` (`lib/rw.sh`) automates routine git-worktree chores for concurrent Claude Code sessions reviewing/working on `jarvis-registry`, invoked from `/Users/kxue/projects/jarvis-registry-workspace`. That workspace now also hosts `jarvis-registry-cli` (a Go project) and its own review worktrees, so a parallel, dedicated command is needed. `rw` is unsuitable to extend with flags because most of its subcommands are hardcoded to Python/`uv` tooling (`uv run poe -q cleanup-artifacts`, `uv sync`, `.venv/bin/activate`) and to Python-project bootstrap artifacts (`.env.*`, `docker-compose.*.yml`, `playwright-cli`) that don't apply to a Go project.

Because both projects' worktree folders live under the same parent directory, `rw`'s worktree-discovery glob in `_kxue43_rw::renew` (`lib/rw.sh:53`, `-name "*-reviews*"`) would incorrectly match the new cli-project folders and run `uv`-based cleanup inside a Go worktree. That must be fixed alongside adding the new command.

---

## Changes

### 1. New module `lib/rcliw.sh`

Mirrors `lib/rw.sh`'s structure (module guard, `_kxue43_rcliw::*` private helpers, public `rcliw()` dispatcher, inline bash completion, `_kxue43_commands_list` registration), adapted as follows:

- **`_kxue43_rcliw::bootstrap`** (vs. `rw.sh:9-20`): only symlinks the shared spec/doc repo. Drops the `.env.*`/`docker-compose.*.yml` symlink loop and the `playwright-cli install --skills` call — neither applies to the Go project.
  ```bash
  _kxue43_rcliw::bootstrap() {
    ln -s ../registry-working-docs/ .working-docs
  }
  ```
- **`_kxue43_rcliw::renew`** (vs. `rw.sh:22-101`): same git pull / display worktree status / rebase-parking-branches / delete-merged-branches flow, with:
  - Both `uv run poe -q cleanup-artifacts` calls removed (the one before `git pull` and the one inside the per-worktree rebase loop).
  - `cd "jarvis-registry"` → `cd "jarvis-registry-cli"` (and matching error message).
  - Worktree discovery glob changed from `*-reviews*` to `cli-*-reviews`, so it only ever matches this project's review folders (`cli-stefan-reviews`, `cli-yulin-reviews`), never `jarvis-registry`'s.
  - Branch-deletion step scoped to `git -C "jarvis-registry-cli"` instead of `git -C "jarvis-registry"`.
- **`_kxue43_rcliw::sync`** (vs. `rw.sh:103-127`): identical git switch/pull logic (branch-arg case and the "not tracking a remote" fallback case), with the `uv sync` and `source .venv/bin/activate` lines dropped — no package-manager step for Go.
- **`_kxue43_rcliw::branch`** (vs. `rw.sh:129-139`): identical, `cd "jarvis-registry"` → `cd "jarvis-registry-cli"`.
- **`_kxue43_rcliw::park`** (vs. `rw.sh:141-166`): identical, base-name check `"jarvis-registry"` → `"jarvis-registry-cli"`.
- **`rcliw()` dispatcher and `-h` help text** (vs. `rw.sh:168-227`): same five subcommands (`bootstrap`, `renew`, `sync [BRANCH]`, `branch`, `park`); help text renamed to `rcliw`/`Jarvis Registry CLI` and the `sync` help text drops the "perform uv sync and activate the virtual environment" clause. Both `-h` heredocs use the quoted `<<'EOF'` form (required for `acmd` preview detection, per this repo's convention).
- **`_kxue43_rcliw::complete`** (vs. `rw.sh:229-258`): identical completion logic (subcommand list + remote-branch completion for `sync`'s `BRANCH` argument), registered as `complete -o bashdefault -F _kxue43_rcliw::complete rcliw`.
- Ends with `_kxue43_commands_list+=("rcliw")` so it appears in `acmd -l`.

Full file content:

```bash
if [[ -n "${_kxue43_module_set_rcliw+x}" ]]; then
  return
fi

_kxue43_module_set_rcliw=1

source "$(cd "$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")" && pwd)/utils.sh"

_kxue43_rcliw::bootstrap() {
  ln -s ../registry-working-docs/ .working-docs
}

_kxue43_rcliw::renew() {
  if ! (
    if ! cd "jarvis-registry-cli"; then
      kxue43::log_error "Failed to cd into jarvis-registry-cli. You are probably not in the correct directory"

      exit 1
    fi

    git pull

    printf "\n"

    kxue43::log_info "Current git worktree status:"

    git branch

    printf "\n"

    read -r -p "Rebase parking branches? [Y/n] " reply

    [[ "${reply:-Y}" =~ ^[Yy]$ ]] || exit 1
  ); then
    kxue43::log_error "Do nothing. Exit"

    return 1
  fi

  local -a worktrees

  mapfile -t worktrees < <(find . -maxdepth 1 -mindepth 1 -type d -name "cli-*-reviews")

  if ((${#worktrees[@]} == 0)); then
    kxue43::log_info "No worktree directories found"

    return 0
  fi

  worktrees=("${worktrees[@]#./}")

  local target
  for target in "${worktrees[@]}"; do
    if [[ "parking/$(basename "$target")" != "$(git -C "$target" branch --show-current)" ]]; then
      continue
    fi

    if ! git -C "$target" rebase main; then
      git -C "$target" rebase --abort

      kxue43::log_error "Failed to rebase parking branch of worktree ${target} onto main"
    fi
  done

  printf "\n"

  local reply
  read -r -p "Delete merged branches? [Y/n] " reply

  [[ "${reply:-Y}" =~ ^[Yy]$ ]] || return 1

  local -a to_delete
  mapfile -t to_delete < <(
    git -C "jarvis-registry-cli" branch |
      awk '/^  / && !/  parking\// { sub(/^  /, ""); print }' |
      fzf -m --height=50% --layout=reverse --bind 'load:select-all'
  )

  if ((${#to_delete[@]} == 0)); then
    kxue43::log_info "No branches selected for deletion"

    return 0
  fi

  git -C "jarvis-registry-cli" branch -D "${to_delete[@]}"
}

_kxue43_rcliw::sync() {
  if (($# > 0)); then
    if ! git ls-remote --exit-code --heads origin "$1" >/dev/null; then
      kxue43::log_error "The remote branch '$1' does not exist."

      return 1
    fi

    git fetch origin

    git switch "$1"

    git pull
  elif [[ "$(git branch --show-current)" != "parking/$(basename "$(pwd)")" ]]; then
    if git rev-parse --abbrev-ref --symbolic-full-name '@{u}' >/dev/null; then
      git pull
    else
      kxue43::log_info "The current branch does not track any remote one. Skip git pull."
    fi
  fi
}

_kxue43_rcliw::branch() {
  (
    if ! cd "jarvis-registry-cli"; then
      kxue43::log_error "Failed to cd into jarvis-registry-cli. You are probably not in the correct directory"

      exit 1
    fi

    git branch
  )
}

_kxue43_rcliw::park() {
  local base
  base="$(basename "$(pwd)")"

  if [[ "$base" == "jarvis-registry-cli" ]]; then
    if ! git checkout main; then
      kxue43::log_error "Failed to check out the main branch"

      return 1
    fi

    return 0
  fi

  if ! git rev-parse --verify "refs/heads/parking/$base" &>/dev/null; then
    kxue43::log_error "No parking branch named 'parking/$base'"

    return 1
  fi

  if ! git checkout "parking/$base"; then
    kxue43::log_error "Failed to check out parking/$base branch"

    return 1
  fi
}

rcliw() {
  if (($# == 0)) || [[ $1 == "-h" ]]; then
    cat <<'EOF'
USAGE: rcliw [-h] [SUBCOMMAND]

SUBCOMMANDS:
    bootstrap               Bootstrap a Jarvis Registry CLI worktree; must be in a worktree folder
    renew                   Pull the latest commits on main; rebase parking branches; delete merged branches; must be in the workspace folder
    sync        [BRANCH]    Pull from the remote branch or switch and pull; must be in a worktree folder
    branch                  List all branches with worktree occupancy markings
    park                    Checkout the corresponding parking branch of the worktree

OPTIONS:
    -h            Show this help message
EOF

    return 0
  fi
  case "$1" in
  bootstrap)
    _kxue43_rcliw::bootstrap
    ;;
  renew)
    _kxue43_rcliw::renew
    ;;
  sync)
    shift 1

    if (($# > 0)) && [[ $1 == "-h" ]]; then
      cat <<'EOF'
Usage: rcliw sync [-h] [BRANCH]

If BRANCH is given, git switch to this remote branch. Then perform git pull.
Must be used in a git worktree folder.

ARGUMENTS:
    BRANCH      The remote branch to git switch to

OPTIONS:
    -h          Show this help message
EOF

      return 0
    fi

    _kxue43_rcliw::sync "$@"
    ;;
  branch)
    _kxue43_rcliw::branch
    ;;
  park)
    _kxue43_rcliw::park
    ;;
  *)
    kxue43::log_error "Unknown subcommand $1"

    return 1
    ;;
  esac
}

_kxue43_rcliw::complete() {
  local -a opts
  opts=("'-h  (Show help message)'" "'bootstrap  (bootstrap worktree)'" "'renew  (Renew workspace)'" "'sync  (Sync worktree)'" "'branch  (List branches)'" "'park  (Checkout parking branch)'")

  if ((COMP_CWORD == 1)) && [[ $2 == "" ]]; then
    compgen -V COMPREPLY -W "${opts[*]}"

    return 0
  elif ((COMP_CWORD == 1)) && [[ $2 =~ ^-h?$ ]]; then
    COMPREPLY=("-h")

    return 0
  elif ((COMP_CWORD == 1)); then
    compgen -V COMPREPLY -W "bootstrap renew sync branch park" -- "$2"

    return 0
  elif ((COMP_CWORD == 2)) && [[ $3 == "sync" ]] && [[ $2 =~ ^-h?$ ]]; then
    compgen -V COMPREPLY -W "-h" -- "$2"

    return 0
  elif ((COMP_CWORD == 2)) && [[ $3 == "sync" ]]; then
    local -a remote_branches

    mapfile -t remote_branches < <(git for-each-ref --format='%(refname:lstrip=3)' refs/remotes/origin | grep -v '^HEAD$')

    compgen -V COMPREPLY -W "${remote_branches[*]}" -- "$2"

    return 0
  fi
} && complete -o bashdefault -F _kxue43_rcliw::complete rcliw

_kxue43_commands_list+=("rcliw")
```

### 2. Tighten `rw`'s worktree-discovery glob so it stops matching cli-project folders

`lib/rw.sh:53` currently reads:

```bash
mapfile -t worktrees < <(find . -maxdepth 1 -mindepth 1 -type d -name "*-reviews*")
```

Since `cli-stefan-reviews`/`cli-yulin-reviews` will sit in the same parent directory as `jarvis-registry`'s own review folders, this glob would also match them, causing `rw renew` to run `uv run poe -q cleanup-artifacts` (`lib/rw.sh:75`) inside a Go worktree that has no `uv`/venv — a hard failure. Change it to exclude the `cli-` prefix:

```bash
mapfile -t worktrees < <(find . -maxdepth 1 -mindepth 1 -type d -name "*-reviews*" ! -name "cli-*")
```

### 3. Source `lib/rcliw.sh` from `profile/ascd.bashrc`

Add the source line next to the existing `lib/rw.sh` line:

`profile/ascd.bashrc:14` currently:
```bash
source "$KXUE43_SUBSTANCE_DIR/lib/rw.sh"
```
becomes:
```bash
source "$KXUE43_SUBSTANCE_DIR/lib/rw.sh"
source "$KXUE43_SUBSTANCE_DIR/lib/rcliw.sh"
```

`rcliw` is only needed in this environment (`ascd`) — do not add it to `profile/kxue43.bashrc` or `dotfiles/.bashrc`.

---

## What does NOT change

- `lib/rw.sh`'s subcommands, help text, and completion logic are otherwise untouched — only the one glob on line 53.
- No changes to `bin/`, `completions/`, or `.pre-commit-config.yaml`. `lib/` modules are sourced directly from the repo path (not symlinked by `set-up.sh`), so no `.keep` bump or `set-up.sh` re-run is needed for this change.
- No `cli-any-reviews` worktree or `-2` duplicate folders — only `cli-stefan-reviews` and `cli-yulin-reviews` are in scope.

---

## Acceptance Criteria

- [ ] `lib/rcliw.sh` exists, passes shellcheck, and follows the module-guard / namespacing conventions in `CLAUDE.md`.
- [ ] `rcliw -h` prints usage listing `bootstrap`, `renew`, `sync [BRANCH]`, `branch`, `park`.
- [ ] Running `rcliw bootstrap` inside a worktree folder creates only the `.working-docs` symlink (no `.env.*`/`docker-compose.*.yml` symlinks, no `playwright-cli` invocation).
- [ ] Running `rcliw renew`'s worktree discovery (`find . -maxdepth 1 -mindepth 1 -type d -name "cli-*-reviews"`) matches `cli-stefan-reviews`/`cli-yulin-reviews` and does not match `stefan-reviews`/`yulin-reviews`/`any-reviews`.
- [ ] `lib/rw.sh:53`'s glob (`*-reviews*` `! -name "cli-*"`) matches `stefan-reviews`, `stefan-reviews-2`, `yulin-reviews`, `yulin-reviews-2`, `any-reviews`, and does not match `cli-stefan-reviews`/`cli-yulin-reviews`.
- [ ] `rcliw sync` performs only git switch/pull (no `uv sync`, no venv activation).
- [ ] `profile/ascd.bashrc` sources `lib/rcliw.sh`; `profile/kxue43.bashrc` and `dotfiles/.bashrc` are unchanged.
- [ ] After implementation, `acmd -d` is run once to invalidate the command cache so `acmd -l`/`acmd -p` picks up `rcliw`.

---

## Files to Change

| File | Change |
|---|---|
| `lib/rcliw.sh` | New file: `rcliw` command (`bootstrap`/`renew`/`sync`/`branch`/`park`) for `jarvis-registry-cli` worktrees |
| `lib/rw.sh` | Line 53: exclude `cli-*` from the `renew` worktree-discovery glob |
| `profile/ascd.bashrc` | Line 14 area: add `source "$KXUE43_SUBSTANCE_DIR/lib/rcliw.sh"` |

---

## Risk

The only change to existing behavior is the `lib/rw.sh:53` glob tightening; the guard is that it must still match all current review-folder names (`stefan-reviews`, `stefan-reviews-2`, `yulin-reviews`, `yulin-reviews-2`, `any-reviews`) exactly as before — verify with a manual `find`/glob check against the real workspace directory before relying on `rw renew` in it.

---

## Out of scope / follow-up

- `jarvis-api`, the third interoperating project mentioned during scoping, has no worktree-automation command in this spec — only `jarvis-registry` (`rw`) and `jarvis-registry-cli` (`rcliw`) are covered.
- If a third `jarvis-registry-cli` reviewer is added later and needs a `-2`-style duplicate worktree, `rcliw`'s discovery glob (`cli-*-reviews`) will need widening to `cli-*-reviews*` to match it.
