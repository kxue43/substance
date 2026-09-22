---
description: >
  Front matter tracks which findings have been posted to GitHub as change requests,
  which have been dismissed, and remaining concerns if any.
  changes_requested is a flow sequence of finding labels posted to GitHub that are still open.
  findings_dismissed is a flow sequence of finding labels the reviewer chose not to post.
  merged is a boolean that tracks if the PR has been merged.
  notes is for optional notes about remaining concerns.
pr_url: https://github.com/kxue43/substance/pull/22
changes_requested: []
findings_dismissed: []
merged:
notes:
---
# PR Review: Refactor: Merge `rcliw` into `rw` with project auto-detection

**PR:** https://github.com/kxue43/substance/pull/22
**Spec:** .working-docs/spec/016-rw-combine.md
**Reviewed:** 2026-09-22

## Summary

The PR implements the spec exactly as written: `_kxue43_rw::detect_project` and
`_kxue43_rw::select_projects` were added verbatim, all five subcommand bodies were split into
`_registry`/`_cli`-suffixed variants (the `_cli` bodies ported byte-for-byte from the deleted
`lib/rcliw.sh`), `bootstrap`/`sync`/`park` became detection-based dispatchers, `renew`/`branch`
became selection-based dispatchers with the `== <project> ==` header behavior, help text was
updated per the spec's exact wording, and `lib/rcliw.sh` plus its two `source` lines were removed.
Runtime testing of the dispatch, header, and error-path logic (see below) confirms it behaves as
specified. No deviations, bugs, or code-quality concerns were found.

## Spec Compliance

| Requirement | Status |
|---|---|
| 1. `_kxue43_rw::detect_project` helper | Met |
| 2. Rename `rw` bodies to `_registry`, port `rcliw` bodies to `_cli` (verbatim) | Met |
| 3. `bootstrap`/`sync`/`park` rewritten as detection dispatchers | Met |
| 4. `_kxue43_rw::select_projects` + `renew`/`branch` selection dispatchers with headers | Met |
| 5. Top-level and `sync` `-h` heredoc updates | Met |
| 6. Delete `lib/rcliw.sh` and its two `source` lines | Met |

All 12 acceptance criteria were verified — either by direct code inspection, or by running the
functions with stubbed collaborators (since the real `jarvis-registry-workspace` worktree layout
isn't available in this repo):

- `rw -h` / `rw sync -h`: printed output matches the spec's exact text.
- `detect_project` inside a repo with an unrecognized `origin` (this `substance` repo itself):
  printed `Unrecognized remote repository: substance` via `kxue43::log_error` and returned 1.
- `bootstrap` dispatcher run outside a matching repo: errored via `detect_project`, performed no
  filesystem action (verified with an empty scratch directory).
- `renew` dispatcher with an empty selection: printed `No project selected` via `kxue43::log_info`,
  returned 0.
- `renew` dispatcher with one vs. both projects selected (stubbed `renew_registry`/`renew_cli`):
  single selection printed no header; both selected printed `== jarvis-registry ==` /
  `== jarvis-registry-cli ==` headers around each project's output, in order.
- `sync` dispatcher forwards `BRANCH` through to `sync_registry`/`sync_cli` correctly for both
  detected projects.
- `shellcheck lib/rw.sh` passes clean.
- `lib/rcliw.sh` no longer exists; no remaining reference to `rcliw` anywhere in the tracked tree.
- `profile/kxue43.bashrc` is a symlink to `profile/ascd.bashrc`, so removing the `source
  .../lib/rcliw.sh` line from the latter removes it from both, as the PR description states.

## Findings

No findings.

### Critical
<!-- none -->

### Major
<!-- none -->

### Minor
<!-- none -->

## Positive Observations

- Every `_cli`-suffixed body is a byte-for-byte port of the corresponding `lib/rcliw.sh` function
  (confirmed by diffing the deleted file's content against the new functions), fully honoring the
  spec's "unchanged, verbatim" requirement and keeping the PR low-risk.
- `detect_project` and `select_projects` are minimal, single-purpose, and match the spec's
  provided code exactly — no scope creep or extra abstraction.
- Error paths (`detect_project` failure, empty project selection) short-circuit before any
  filesystem or git mutation, matching the acceptance criteria precisely.
- Help text updates read naturally and accurately describe the new auto-detection/selection
  behavior.

## Recommendation

**Approve** — the implementation matches the spec exactly, passes shellcheck, and all
dispatch/error-path behavior was verified at runtime with no issues found.
