# Move `verify-sha` into `kxue43-pr-review` and make every failure print `ERROR:`

## Background

Spec 014 moved `fetch-pr-data` and `fetch-pr-comments` into
`.claude/skills/kxue43-pr-review/scripts/` so the skill folder could be dropped into a teammate's
`~/.claude/skills/` and work on its own. It left `bin/verify-sha` out
(`.working-docs/spec/014-inline-skill-scripts.md:709`). Step 1 of both subcommands still runs a
bare `verify-sha` (`.claude/skills/kxue43-pr-review/SKILL.md:32`). That command is on `PATH` only
because `set-up.sh:187-189` symlinks `bin/` into `~/.local/bin`, so for anyone else the skill
fails at its first step. `verify-sha` has no other callers: a grep of the repo finds it only in
`bin/verify-sha`, `completions/verify-sha`, and `SKILL.md:26,32`.

There are also two ways a failed check gets treated as a pass:

- `SKILL.md:35-36` stops only if stdout starts with `VERIFY-SHA: FAIL` and says "Otherwise
  continue". An `ERROR: …` line, such as the one from `bin/verify-sha:38` when `git ls-remote`
  fails, lets the review go ahead with the SHA unchecked.
- Under `set -eu -o pipefail` (`bin/verify-sha:3`), the command substitutions at
  `bin/verify-sha:31`, `:33`, `:44` and `:53` are not guarded. If any of them fails, the script
  exits non-zero with nothing on stdout. Two cases were checked by hand:
  - Outside a git repo: exit 128, empty stdout, and `fatal: not a git repository` on stderr only.
  - On an unborn branch (`git init`, no commits): exit 128, empty stdout, and
    `fatal: ambiguous argument 'HEAD'` on stderr only.

---

## Changes

### 1. Move the script into the skill folder

Move `bin/verify-sha` to `.claude/skills/kxue43-pr-review/scripts/verify-sha` and keep it
executable. Delete the `source "…/../lib/utils.sh"` line (`bin/verify-sha:5`). The script calls
none of the functions `lib/utils.sh` defines (`kxue43::log_error`, `kxue43::log_info`,
`kxue43::get_env_prefix`), and spec 014 already required skill scripts to reference nothing
outside their own skill directory.

Delete `completions/verify-sha`. Completions load from `$KXUE43_SUBSTANCE_DIR/completions/`
(`lib/it-shell.sh:95`), and a command that is no longer on `PATH` doesn't need one.

Remove the leftover `~/.local/bin/verify-sha` symlink:
- In this clone, run `./set-up.sh` locally. Its cleanup loop (`set-up.sh:194-200`) removes the
  symlink because its target is no longer executable.
- For other clones, run `date > .keep` so their `post-merge` hook re-runs `set-up.sh`
  (`.pre-commit-config.yaml`).

Run `acmd -d`, because `lib/acmd.sh:83` builds its cache from `bin/*`.

### 2. Print `ERROR: <reason>` on every failure path in `verify-sha`

Every command whose failure `set -e` would turn into a silent exit must either be guarded with
`if ! …; then echo "ERROR: …"; return 0; fi`, or be replaced by a builtin that cannot fail. This
matches how `fetch-pr-data` handles its errors (`scripts/fetch-pr-data:47-51`). Line numbers
below refer to the current `bin/verify-sha`.

- **Create the temp file first** (`:33-34`). Move `stderr_file=$(mktemp)` and its `EXIT` trap so
  they come right after the argument check (`:24-28`) and before the first `git` call. Guard the
  call as `if ! stderr_file=$(mktemp 2>&1); then echo "ERROR: $stderr_file"; return 0; fi`, so
  mktemp's own error message becomes the reason.
  - Keep `stderr_file` global, not `local`. The `EXIT` trap runs after `main` has returned, and
    under `set -u` a `local` variable would be unbound inside the trap.
- **Branch lookup** (`:31`). Change it to
  `if ! branch=$(git rev-parse --abbrev-ref HEAD 2>"$stderr_file"); then echo "ERROR: $(<"$stderr_file")"; return 0; fi`.
  This covers "not a git repository", an unborn branch, and a missing `git` binary.
- **Parse the remote SHA** (`:44`). Replace the `awk` call with
  `remote_sha=${ls_remote_output%%[[:space:]]*}`. `git ls-remote` prints `<sha>\t<ref>`, so the
  parameter expansion returns the same SHA without an external process that could fail.
  - One difference: if `ls-remote` returns several lines, this keeps only the first SHA. `awk`
    returned the first field of every line joined by newlines, which could never equal a single
    SHA.
- **Local SHA** (`:53`). Guard `local_sha=$(git rev-parse HEAD 2>"$stderr_file")` the same way as
  the branch lookup.
- **Help text** (`:12-15`). Replace "Prints a fixed plain-text format to stdout" with the actual
  contract: stdout is `VERIFY-SHA: PASS`, `VERIFY-SHA: FAIL — <details>`, or
  `ERROR: <reason>`, and the script exits 0 in every case except `-h`.

These paths already work and keep their current output:
- The argument-count `ERROR` (`:24-28`).
- The `git ls-remote` guard (`:37-41`).
- Both `FAIL` lines (`:46-50`, `:55-59`).
- `PASS` (`:61`).

### 3. Update the Verify SHA step in `SKILL.md`

In `.claude/skills/kxue43-pr-review/SKILL.md`:

- **Invocation** (`:31-33`). Change the command to `${CLAUDE_SKILL_DIR}/scripts/verify-sha`, in
  the same form as the `fetch-pr-data` call at `:69-71`.
- **Stop rule** (`:35-36`). Continue only if stdout is exactly `VERIFY-SHA: PASS`. On anything
  else, stop immediately and relay the output verbatim to the user. "Anything else" means a
  `VERIFY-SHA: FAIL …` line, an `ERROR: …` message, or empty stdout; if stdout is empty, include
  any stderr. Checking for PASS instead of looking for known failure prefixes also covers cases
  where the script can't run at all, such as a missing file or the executable bit not set.

`followup` Step 1 (`SKILL.md:239-242`) points to this shared procedure and needs no edit.

---

## What does NOT change

- The output text for PASS and both FAIL cases, and the no-argument interface.
- Output is still printed to stdout directly. The write-to-a-temp-file-and-print-the-path
  pattern from spec 014 is for large output; this script prints a single line.
- `allowed-tools` in `SKILL.md:7` stays as the unrestricted `Bash` grant.
- `set-up.sh`, `lib/utils.sh` and `lib/acmd.sh` need no code changes.

---

## Acceptance Criteria

- [ ] `.claude/skills/kxue43-pr-review/scripts/verify-sha` exists and is executable.
      `bin/verify-sha` and `completions/verify-sha` no longer exist.
- [ ] The relocated script contains no `source` line and no reference to `lib/utils.sh`.
- [ ] After `./set-up.sh`, `command -v verify-sha` prints nothing. After `acmd -d`, `acmd -l`
      does not list `verify-sha`.
- [ ] Each run below of `…/scripts/verify-sha` exits 0 and prints the stdout shown:
  - [ ] In a directory that is not a git repo: starts with
        `ERROR: fatal: not a git repository`.
  - [ ] In a fresh `git init` repo with no commits: starts with
        `ERROR: fatal: ambiguous argument 'HEAD'`.
  - [ ] With `PATH` starting with a directory whose `mktemp` prints `mktemp: boom` to stderr and
        exits 1: exactly `ERROR: mktemp: boom`.
  - [ ] In a repo with a commit but no `origin` remote: starts with
        `ERROR: fatal: 'origin' does not appear to be a git repository`. This matches today's
        output.
  - [ ] With detached HEAD and a reachable `origin`:
        `VERIFY-SHA: FAIL — no remote ref found for branch HEAD`.
  - [ ] With local HEAD equal to the remote branch: `VERIFY-SHA: PASS`. With a local commit
        that hasn't been pushed: `VERIFY-SHA: FAIL — local <sha> ≠ remote <sha>`.
  - [ ] With one positional argument:
        `ERROR: verify-sha takes no positional arguments`.
- [ ] `SKILL.md` runs the script only as `${CLAUDE_SKILL_DIR}/scripts/verify-sha`, and a grep
      finds no bare `verify-sha` invocation.
- [ ] `SKILL.md`'s Verify SHA procedure says to continue only when stdout is exactly
      `VERIFY-SHA: PASS`, and to stop and relay the output otherwise.
- [ ] `.keep` has been updated with `date > .keep` and committed with these changes.
- [ ] `/kxue43-pr-review start` run against a real PR gets past Step 1 on a synced branch, and
      stops with the `ERROR:` output when started from a non-git directory.

---

## Files to Change

| File | Change |
|---|---|
| `bin/verify-sha` | Deleted (moved) |
| `.claude/skills/kxue43-pr-review/scripts/verify-sha` | New: the moved script. Drops the `lib/utils.sh` source line, creates the temp file before the first `git` call, guards `mktemp` and both `git rev-parse` calls with `ERROR:` output, replaces `awk` with parameter expansion, and updates the help text |
| `completions/verify-sha` | Deleted |
| `.claude/skills/kxue43-pr-review/SKILL.md` | Verify SHA procedure (`:31-36`): run via `${CLAUDE_SKILL_DIR}/scripts/verify-sha`, and continue only on exactly `VERIFY-SHA: PASS` |
| `.keep` | Update with `date > .keep` so other clones re-run `set-up.sh` |

---

## Risk

The main regression risk is the stricter stop rule in `SKILL.md`: an unexpected but harmless
change to the PASS line, such as trailing text, would now stop every review. Nothing tests this
automatically, so the scratch-repo runs above and one end-to-end `/kxue43-pr-review start` are
the only checks.

---

## Out of scope / follow-up

- With detached HEAD, `git rev-parse --abbrev-ref HEAD` returns the literal `HEAD`, so the check
  reports "no remote ref found for branch HEAD" instead of saying HEAD is detached. The review
  still stops correctly; only the message is misleading.
- The script hardcodes the `origin` remote (`bin/verify-sha:37`). A PR checked out from a fork
  remote under a different name fails with a `git ls-remote` `ERROR:`.
