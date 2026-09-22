# Combine `rw` and `rcliw` into a Single `rw` Command

## Background

`lib/rw.sh` (`rw`) and `lib/rcliw.sh` (`rcliw`) are two near-parallel interactive commands used
under `~/projects/jarvis-registry-workspace` (a git-worktree workspace holding worktrees of both
`ascending-llc/jarvis-registry` and `ascending-llc/jarvis-registry-cli`). Both expose the same five
subcommands (`bootstrap`, `renew`, `sync [BRANCH]`, `branch`, `park`), but only differ in which
project directory they target and in a handful of project-specific behaviors (`lib/rw.sh:9-20` vs
`lib/rcliw.sh:9-11` for `bootstrap`; `lib/rw.sh:103-127` vs `lib/rcliw.sh:88-108` for `sync`;
`lib/rw.sh:22-101` vs `lib/rcliw.sh:13-86` for `renew`). In practice, muscle memory has formed
around `rw`, making `rcliw` awkward to reach for. Of the five subcommands, `bootstrap`, `sync`, and
`park` are always invoked from inside a single project's worktree folder (so the target project can
be detected from that folder's git remote), while `renew` and `branch` are invoked from the shared
workspace root and need an explicit choice of which project(s) to act on. This spec merges both
commands into one `rw`, preserving every existing per-project behavior, and removes `rcliw`.

---

## Changes

### 1. Add a shared project-detection helper

Add a new private helper to `lib/rw.sh` (near the top, after the `source ".../utils.sh"` line at
`lib/rw.sh:7`) that identifies which project the current git worktree belongs to by resolving the
`origin` remote URL's repo name — this works uniformly for SSH and HTTPS remotes and for both the
main checkout and any linked worktree, since worktrees share the same remotes:

```bash
_kxue43_rw::detect_project() {
  local remote_url
  if ! remote_url="$(git remote get-url origin 2>/dev/null)"; then
    kxue43::log_error "Not inside a git repository with an 'origin' remote"

    return 1
  fi

  case "$(basename "$remote_url" .git)" in
  jarvis-registry)
    printf 'registry\n'
    ;;
  jarvis-registry-cli)
    printf 'cli\n'
    ;;
  *)
    kxue43::log_error "Unrecognized remote repository: $(basename "$remote_url" .git)"

    return 1
    ;;
  esac
}
```

### 2. Rename existing `rw` project-specific bodies and port `rcliw`'s bodies alongside them

For each of `bootstrap`, `sync`, and `park`, rename the existing `_kxue43_rw::<subcommand>` function
(the current registry-only body) to `_kxue43_rw::<subcommand>_registry`, and add a new
`_kxue43_rw::<subcommand>_cli` function containing the corresponding body currently in
`lib/rcliw.sh`, verbatim:

- `_kxue43_rw::bootstrap_registry` ← current `_kxue43_rw::bootstrap` body (`lib/rw.sh:9-20`,
  unchanged: symlinks `.working-docs`, the four `.env.*`/`docker-compose.*.yml` files, and installs
  the `playwright-cli` Claude skill).
- `_kxue43_rw::bootstrap_cli` ← `lib/rcliw.sh:9-11` body, unchanged (symlinks `.working-docs` only).
- `_kxue43_rw::sync_registry` ← current `_kxue43_rw::sync` body (`lib/rw.sh:103-127`, unchanged:
  git switch/pull logic followed by `uv sync` and `source .venv/bin/activate`).
- `_kxue43_rw::sync_cli` ← `lib/rcliw.sh:88-108` body, unchanged (same git switch/pull logic, no
  `uv sync`/venv activation).
- `_kxue43_rw::park_registry` ← current `_kxue43_rw::park` body (`lib/rw.sh:141-166`, unchanged).
- `_kxue43_rw::park_cli` ← `lib/rcliw.sh:122-147` body, unchanged (same structure, basename check
  against `"jarvis-registry-cli"` instead of `"jarvis-registry"`).

Same pattern for `renew` and `branch`, since their bodies also need to be callable individually per
selected project (see Change 3):

- `_kxue43_rw::renew_registry` ← current `_kxue43_rw::renew` body (`lib/rw.sh:22-101`, unchanged).
- `_kxue43_rw::renew_cli` ← `lib/rcliw.sh:13-86` body, unchanged (no `cleanup-artifacts` calls,
  worktree glob `cli-*-reviews` instead of `*-reviews* ! -name "cli-*"`).
- `_kxue43_rw::branch_registry` ← current `_kxue43_rw::branch` body (`lib/rw.sh:129-139`, unchanged).
- `_kxue43_rw::branch_cli` ← `lib/rcliw.sh:110-120` body, unchanged.

### 3. Rewrite `bootstrap`, `sync`, and `park` as project-detecting dispatchers

Replace the (now renamed) `_kxue43_rw::bootstrap`, `_kxue43_rw::sync`, `_kxue43_rw::park` entry
points with thin dispatchers that call `_kxue43_rw::detect_project` and route to the `_registry` or
`_cli` variant:

```bash
_kxue43_rw::bootstrap() {
  local project
  project="$(_kxue43_rw::detect_project)" || return 1

  case "$project" in
  registry)
    _kxue43_rw::bootstrap_registry
    ;;
  cli)
    _kxue43_rw::bootstrap_cli
    ;;
  esac
}

_kxue43_rw::sync() {
  local project
  project="$(_kxue43_rw::detect_project)" || return 1

  case "$project" in
  registry)
    _kxue43_rw::sync_registry "$@"
    ;;
  cli)
    _kxue43_rw::sync_cli "$@"
    ;;
  esac
}

_kxue43_rw::park() {
  local project
  project="$(_kxue43_rw::detect_project)" || return 1

  case "$project" in
  registry)
    _kxue43_rw::park_registry
    ;;
  cli)
    _kxue43_rw::park_cli
    ;;
  esac
}
```

`_kxue43_rw::sync` must keep forwarding `"$@"` so the optional `BRANCH` argument still reaches the
underlying `_registry`/`_cli` implementation.

### 4. Add a project-selection helper and rewrite `renew`/`branch` as selection-driven dispatchers

Add a shared selector, following the existing multi-select pattern already used for branch deletion
in `_kxue43_rw::renew` (`lib/rw.sh:88-92`, referenced during design as `lib/rcliw.sh#L76`), defaulting
to both projects selected:

```bash
_kxue43_rw::select_projects() {
  local -a selected
  mapfile -t selected < <(
    printf '%s\n' "jarvis-registry" "jarvis-registry-cli" |
      fzf -m --height=50% --layout=reverse --bind 'load:select-all'
  )

  printf '%s\n' "${selected[@]}"
}
```

Replace the (now renamed) `_kxue43_rw::renew` and `_kxue43_rw::branch` entry points with dispatchers
that prompt for project selection, then loop over the selection sequentially. When more than one
project is selected, print a `== <project> ==` header before each project's output so combined
`renew`/`branch` output stays attributable; when exactly one is selected, no header is printed:

```bash
_kxue43_rw::renew() {
  local -a projects
  mapfile -t projects < <(_kxue43_rw::select_projects)

  if ((${#projects[@]} == 0)); then
    kxue43::log_info "No project selected"

    return 0
  fi

  local project
  for project in "${projects[@]}"; do
    if ((${#projects[@]} > 1)); then
      printf '\n== %s ==\n\n' "$project"
    fi

    case "$project" in
    jarvis-registry)
      _kxue43_rw::renew_registry
      ;;
    jarvis-registry-cli)
      _kxue43_rw::renew_cli
      ;;
    esac
  done
}

_kxue43_rw::branch() {
  local -a projects
  mapfile -t projects < <(_kxue43_rw::select_projects)

  if ((${#projects[@]} == 0)); then
    kxue43::log_info "No project selected"

    return 0
  fi

  local project
  for project in "${projects[@]}"; do
    if ((${#projects[@]} > 1)); then
      printf '\n== %s ==\n\n' "$project"
    fi

    case "$project" in
    jarvis-registry)
      _kxue43_rw::branch_registry
      ;;
    jarvis-registry-cli)
      _kxue43_rw::branch_cli
      ;;
    esac
  done
}
```

Each selected project's existing confirmation prompts (e.g. "Rebase parking branches? [Y/n]",
"Delete merged branches? [Y/n]" inside `_kxue43_rw::renew_registry`/`_kxue43_rw::renew_cli`) still
fire once per project when both are selected — this is unchanged from each function's current
behavior, just invoked twice in sequence instead of via two separate top-level commands.

### 5. Update `rw`'s help text

The public `rw()` dispatcher's `case` statement (`lib/rw.sh:186-226`) keeps calling
`_kxue43_rw::bootstrap`, `_kxue43_rw::renew`, `_kxue43_rw::sync "$@"`, `_kxue43_rw::branch`,
`_kxue43_rw::park` — no change to the dispatch table itself. Update the top-level `-h` heredoc
(`lib/rw.sh:170-182`) to describe the new auto-detection/selection behavior:

```
USAGE: rw [-h] [SUBCOMMAND]

SUBCOMMANDS:
    bootstrap               Bootstrap a jarvis-registry or jarvis-registry-cli worktree (project auto-detected via git remote); must be in a worktree folder
    renew                   Pull the latest commits on main; rebase parking branches; delete merged branches, for the selected project(s); must be in the workspace folder
    sync        [BRANCH]    Pull from the remote branch or switch and pull (project auto-detected via git remote; additionally runs uv sync and activates the virtual environment for jarvis-registry only); must be in a worktree folder
    branch                  List all branches with worktree occupancy markings, for the selected project(s); must be in the workspace folder
    park                    Checkout the corresponding parking branch of the worktree (project auto-detected via git remote)

OPTIONS:
    -h            Show this help message
```

Also update the `sync` subcommand's own `-h` heredoc (`lib/rw.sh:197-208`) to note the
registry-only `uv sync`/venv-activation step, e.g. append: "For jarvis-registry worktrees, this
additionally runs uv sync and activates the virtual environment; jarvis-registry-cli worktrees skip
this step."

### 6. Delete `lib/rcliw.sh` and its `source` lines

Delete `lib/rcliw.sh` entirely (its `_kxue43_commands_list+=("rcliw")` registration at
`lib/rcliw.sh:241` is removed along with the file). Remove the line
`source "$KXUE43_SUBSTANCE_DIR/lib/rcliw.sh"` from both `profile/ascd.bashrc:15` and
`profile/kxue43.bashrc:15` (both files currently source it identically).

---

## What does NOT change

- The underlying per-project behavior bodies — registry-only `uv sync`/venv activation, registry-only
  `uv run poe -q cleanup-artifacts` calls, the differing worktree-discovery globs
  (`*-reviews* ! -name "cli-*"` vs `cli-*-reviews`), and `park`'s basename checks — are preserved
  verbatim, just relocated into `_registry`/`_cli`-suffixed functions.
- `_kxue43_rw::complete` (`lib/rw.sh:229-258`) and its `complete -o bashdefault -F _kxue43_rw::complete
  rw` registration: unchanged. It is already project-agnostic (the `sync` `BRANCH` completion reads
  remote branches of whatever repo the shell is currently in).
- `rw`'s top-level subcommand names (`bootstrap`, `renew`, `sync [BRANCH]`, `branch`, `park`) and its
  `case` dispatch structure at `lib/rw.sh:186-226`.
- The module-load guard (`_kxue43_module_set_rw`, `lib/rw.sh:1-5`) and the
  `_kxue43_commands_list+=("rw")` registration (`lib/rw.sh:260`).
- No third project (e.g. `jarvis-api`) is added to project detection or selection.

---

## Acceptance Criteria

- [ ] `rw -h` prints usage listing the same five subcommands, with descriptions updated per Change 5.
- [ ] Running `rw bootstrap` inside a `jarvis-registry` worktree symlinks `.working-docs`, the four
      `.env.*`/`docker-compose.*.yml` files, and attempts the `playwright-cli install --skills` call.
- [ ] Running `rw bootstrap` inside a `jarvis-registry-cli` worktree symlinks only `.working-docs`.
- [ ] Running `rw sync` inside a `jarvis-registry` worktree performs `uv sync` and activates
      `.venv/bin/activate`; inside a `jarvis-registry-cli` worktree it does not.
- [ ] Running `rw bootstrap`, `rw sync`, or `rw park` outside a git repo, or inside a git repo whose
      `origin` remote does not resolve to `jarvis-registry` or `jarvis-registry-cli`, prints an error
      via `kxue43::log_error` and returns non-zero without performing any filesystem or git action.
- [ ] Running `rw renew` or `rw branch` shows an fzf multi-select of `jarvis-registry` and
      `jarvis-registry-cli` with both pre-selected (`load:select-all`).
- [ ] Confirming both projects in the picker runs each project's existing `renew`/`branch` logic
      sequentially, each preceded by a `== <project> ==` header.
- [ ] Selecting a single project in the picker runs only that project's logic, with no header printed.
- [ ] Deselecting both projects in the picker prints "No project selected" via `kxue43::log_info` and
      returns 0 without error.
- [ ] `lib/rcliw.sh` no longer exists, and `rcliw` is not a defined command in a freshly sourced shell.
- [ ] `profile/ascd.bashrc` and `profile/kxue43.bashrc` no longer contain a `source .../lib/rcliw.sh`
      line.
- [ ] After running `acmd -d`, `acmd -l` lists `rw` and does not list `rcliw`.
- [ ] `shellcheck lib/rw.sh` passes clean.

---

## Files to Change

| File | Change |
|---|---|
| `lib/rw.sh` | Add `_kxue43_rw::detect_project` and `_kxue43_rw::select_projects`; rename existing `bootstrap`/`sync`/`park`/`renew`/`branch` bodies to `_registry`-suffixed variants; add ported `_cli`-suffixed variants from `lib/rcliw.sh`; rewrite `bootstrap`/`sync`/`park` as `detect_project`-based dispatchers and `renew`/`branch` as selection-based dispatchers with `== <project> ==` headers; update the top-level and `sync` `-h` heredocs |
| `lib/rcliw.sh` | Delete |
| `profile/ascd.bashrc` | Remove `source "$KXUE43_SUBSTANCE_DIR/lib/rcliw.sh"` (line 15) |
| `profile/kxue43.bashrc` | Remove `source "$KXUE43_SUBSTANCE_DIR/lib/rcliw.sh"` (line 15) |

---

## Risk

The main risk is `_kxue43_rw::detect_project` misbehaving in a worktree whose `origin` remote is
absent, renamed, or points at a fork whose URL doesn't end in `jarvis-registry`/`jarvis-registry-cli`
(silently routing to the wrong project's behavior or erroring where the old commands worked);
mitigated by the explicit unrecognized-remote/no-remote error paths in `detect_project` and by
manually exercising `bootstrap`/`sync`/`park` in both a real `jarvis-registry` and
`jarvis-registry-cli` worktree before relying on the merged command day-to-day.
