---
description: >
  Front matter tracks which findings have been posted to GitHub as change requests,
  which have been dismissed, and remaining concerns if any.
  changes_requested is a flow sequence of finding labels posted to GitHub that are still open.
  findings_dismissed is a flow sequence of finding labels the reviewer chose not to post.
  merged is a boolean that tracks if the PR has been merged.
  notes is for optional notes about remaining concerns.
pr_url: https://github.com/kxue43/substance/pull/20
changes_requested: []
findings_dismissed: []
merged: true
notes:
---
# PR Review: Feature: add the `rcliw` command

**PR:** https://github.com/kxue43/substance/pull/20
**Spec:** .working-docs/spec/015-rcliw.md
**Reviewed:** 2026-09-08

## Summary

This PR adds `lib/rcliw.sh`, a `jarvis-registry-cli` worktree-automation command mirroring `lib/rw.sh`, tightens `rw`'s worktree-discovery glob to exclude `cli-*` folders, and sources the new module from `profile/ascd.bashrc`. The implementation is a byte-for-byte match of the spec's prescribed file content and diff snippets. `shellcheck` passes clean on both `lib/rcliw.sh` and `lib/rw.sh`, and both worktree-discovery glob patterns were empirically verified against the exact folder names listed in the spec's acceptance criteria.

## Spec Compliance

| Criterion | Status |
|---|---|
| `lib/rcliw.sh` exists, passes shellcheck, follows module-guard/namespacing conventions | Met |
| `rcliw -h` lists all five subcommands | Met |
| `rcliw bootstrap` creates only the `.working-docs` symlink | Met |
| `rcliw renew`'s glob matches `cli-stefan-reviews`/`cli-yulin-reviews`, not `stefan-reviews`/`yulin-reviews`/`any-reviews` | Met (verified via `find` against synthetic dirs) |
| `rw.sh:53`'s glob matches all pre-existing review-folder names, excludes `cli-*` | Met (verified via `find` against synthetic dirs) |
| `rcliw sync` performs only git switch/pull, no `uv sync`/venv activation | Met |
| `profile/ascd.bashrc` sources `lib/rcliw.sh`; `kxue43.bashrc`/`dotfiles/.bashrc` unchanged | Met (confirmed via diff) |
| `acmd -d` run once after implementation | Not verifiable from the diff — `_acmd_cache` is gitignored and this is a local runtime step, not a code change |

## Findings

No Critical, Major, or Minor findings.

### Critical
<!-- none -->

### Major
<!-- none -->

### Minor
<!-- none -->

## Positive Observations

- Faithful, disciplined mirroring of `rw.sh`'s structure and conventions (module guard, `_kxue43_rcliw::*` namespacing, quoted `<<'EOF'` heredocs, inline completion) — no scope creep beyond what the spec called for.
- All Python/`uv`-specific pieces (`uv sync`, venv activation, `.env.*`/`docker-compose.*.yml` symlinks, `playwright-cli`) were cleanly dropped rather than stubbed out or left commented.
- The `rw.sh` glob fix is minimal and surgical — a single line, additive `! -name "cli-*"` exclusion — with no collateral changes to unrelated `rw` behavior, matching the "What does NOT change" section of the spec exactly.
- `profile/kxue43.bashrc` and `dotfiles/.bashrc` were correctly left untouched, respecting the environment-scoping call-out in the spec.

## Recommendation

**Approve** — implementation matches the spec exactly, passes shellcheck, and both glob changes were empirically verified against the acceptance criteria's example folder names with no discrepancies.
