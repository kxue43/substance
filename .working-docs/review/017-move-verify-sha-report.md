---
description: >
  Front matter tracks which findings have been posted to GitHub as change requests,
  which have been dismissed, and remaining concerns if any.
  changes_requested is a flow sequence of finding labels posted to GitHub that are still open.
  findings_dismissed is a flow sequence of finding labels the reviewer chose not to post.
  merged is a boolean that tracks if the PR has been merged.
  notes is for optional notes about remaining concerns.
pr_url: https://github.com/kxue43/substance/pull/24
changes_requested: [m1]
findings_dismissed: []
merged:
notes:
---
# PR Review: Feature: Move `verify-sha` into `kxue43-pr-review` and make every failure print `ERROR:`

**PR:** https://github.com/kxue43/substance/pull/24
**Spec:** .working-docs/spec/017-move-verify-sha.md
**Reviewed:** 2026-09-23

## Summary

The PR does what spec 017 asks for, and every scripted acceptance scenario reproduces exactly in
scratch repos. The script now lives in the skill folder, every `set -e` exit path prints an
`ERROR:` line, and `SKILL.md` continues only on an exact `VERIFY-SHA: PASS`. The one new gap is in
the `awk` → parameter-expansion swap the spec requested: when `git ls-remote` returns more than one
line, the script now compares against whichever line sorts first. So a narrow case that used to
fail closed can now pass.

## Spec Compliance

| Requirement | Status | Evidence |
|---|---|---|
| Script moved to `scripts/verify-sha`, executable; `bin/verify-sha` and `completions/verify-sha` removed | Met | Diff is a rename (`bin/verify-sha` → `.claude/skills/kxue43-pr-review/scripts/verify-sha`, mode 100755); completion file deleted |
| No `source` line / no `lib/utils.sh` reference | Met | `scripts/verify-sha:1-5` |
| `command -v verify-sha` empty after `./set-up.sh`; `acmd -l` doesn't list it | Met | `~/.local/bin/verify-sha` absent, `command -v` exits 1; `_acmd_cache` has no `verify` entry |
| Temp file created first, guarded; `stderr_file` global | Met | `scripts/verify-sha:34-39` |
| Branch lookup and local SHA guarded with `ERROR:` | Met | `scripts/verify-sha:42-46`, `:64-68` |
| `awk` replaced by `${ls_remote_output%%[[:space:]]*}` | Met, but see **[m1]** | `scripts/verify-sha:55` |
| Help text states the stdout contract and exit-0 behavior | Met | `scripts/verify-sha:12-19` |
| Scenario: not a git repo → `ERROR: fatal: not a git repository…` | Met | Reproduced, rc=0 |
| Scenario: unborn branch → `ERROR: fatal: ambiguous argument 'HEAD'…` | Met | Reproduced, rc=0 |
| Scenario: fake `mktemp` → exactly `ERROR: mktemp: boom` | Met | Reproduced, rc=0 |
| Scenario: no `origin` → `ERROR: fatal: 'origin' does not appear…` | Met | Reproduced, rc=0 |
| Scenario: detached HEAD → `FAIL — no remote ref found for branch HEAD` | Met | Reproduced, rc=0 |
| Scenario: synced → `PASS`; unpushed commit → `FAIL — local … ≠ remote …` | Met | Reproduced, rc=0 |
| Scenario: positional arg → `ERROR: verify-sha takes no positional arguments` | Met | Reproduced, rc=0. Also checked: missing `git` binary → `ERROR: …: git: command not found`, rc=0 |
| `SKILL.md` invokes only `${CLAUDE_SKILL_DIR}/scripts/verify-sha` | Met | `SKILL.md:32`; grep finds no bare invocation |
| `SKILL.md` continues only on exact `VERIFY-SHA: PASS`, relays otherwise | Met | `SKILL.md:35-38`; `followup` Step 1 (`SKILL.md:241-244`) still defers to it |
| `.keep` bumped and committed | Met | Commit 5906052 |
| E2E `/kxue43-pr-review start` passes Step 1 on a synced branch; stops on non-git dir | Met (synced half seen in this review; non-git half checked at the script level only) | This review got `VERIFY-SHA: PASS` at Step 1 |
| What does NOT change (PASS/FAIL text, stdout output, `allowed-tools`, `set-up.sh`/`lib/*`) | Met | Not touched by the diff |

Outside the spec's Files to Change, commit 3c94056 adds a `tartufo.toml` exclusion. I recomputed
its blake2s signature: it covers the string `KXUE43_SUBSTANCE_DIR/completions/` in
`.working-docs/spec/017-move-verify-sha.md`, so the "file path is not credential" reason is
correct.

## Findings

### Critical

None.

### Major

None.

### Minor

**[m1] The first-SHA parse can wrongly PASS when `git ls-remote` returns more than one ref** —
`scripts/verify-sha:55` takes the SHA from the first line of `git ls-remote origin
"refs/heads/$branch"`. But `ls-remote` matches patterns against the tail of the ref name, so a
remote branch whose name ends in `/refs/heads/<branch>` also matches. Its line sorts first when its
prefix sorts before `refs/heads/<branch>` (e.g. `aaa/…`). I reproduced this in a scratch repo. The
remote had `refs/heads/master` at `2b3918c` and a decoy `refs/heads/aaa/refs/heads/master` at
`65c39e0`. Local HEAD was `65c39e0`. The script printed `VERIFY-SHA: PASS` even though local HEAD
≠ the real remote branch. With the old `awk` code, any multi-line output could never match, so this
case always failed. The spec did note the change ("this keeps only the first SHA"), but its reasoning
misses that the new behavior fails open, which works against the PR's fail-closed goal. It only
happens with a contrived branch name, which is why this is Minor. Fix with builtins only, by
choosing the line whose ref is exactly `refs/heads/$branch`:

```bash
local remote_sha="" sha ref
while read -r sha ref; do
  if [[ $ref == "refs/heads/$branch" ]]; then
    remote_sha=$sha
  fi
done <<<"$ls_remote_output"
```

I tested this under `set -eu -o pipefail`: it picks the correct SHA whichever order the lines come
in, and it leaves `remote_sha` empty (so the existing "no remote ref found" FAIL fires) for empty
output or decoy-only output. Use `if`, not `[[ … ]] && …`, so the loop body's status can't
interact with `set -e`.

## Positive Observations

- Every guard follows the `if ! x=$(… 2>"$stderr_file"); then echo "ERROR: …"; return 0; fi`
  shape already used in `fetch-pr-data`. Git's stderr always goes to the temp file, so the script's
  own stderr stays empty on every path I tested. That keeps the "exactly PASS" rule in `SKILL.md`
  unambiguous.
- `mktemp 2>&1` inside the guard turns mktemp's own message into the `ERROR:` reason, and
  `stderr_file` stays global so the `EXIT` trap is safe under `set -u`.
- Checking for PASS instead of known failure prefixes in `SKILL.md` also covers a missing or
  non-executable script and any failure mode added later.
- The help text now describes the actual output contract. `shellcheck` reports nothing.
- The commit message and PR body explain the reasons behind the change, not only what changed.

## Recommendation

**Approve** — the spec is fully met and verified by running it. [m1] is a narrow fail-open in the
new parsing that is cheap to close, but it doesn't block merging.
