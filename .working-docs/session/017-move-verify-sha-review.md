---
load:
  - .working-docs/spec/017-move-verify-sha.md
  - .working-docs/review/017-move-verify-sha-report.md
base_branch: main
next_labels:
  C: 1
  M: 1
  m: 2
---

# Session Notes

<!--
  `load:` paths are relative to CWD, not to this file.
  The last entry in `load:` is always the report file. All entries before it are spec or
  spec-like files. The user may manually add more spec-like files between sessions, but
  the last entry is always the report file.
  Record prior session conclusions, open questions, and constraints here.
  Write it as a future-you artifact.
-->

## Start session (2026-09-23, HEAD 5906052)

- Every spec 017 acceptance scenario was reproduced in scratch repos (exit 0, expected stdout),
  plus a missing-`git` case. Local state was checked: `~/.local/bin/verify-sha` is gone and
  `_acmd_cache` has no entry for it. `shellcheck` reports nothing.
- The `tartufo.toml` exclusion added in 3c94056 is benign. Its signature was recomputed and
  covers `KXUE43_SUBSTANCE_DIR/completions/` in the spec 017 file.
- [m1] was accepted. To verify a fix in followup: create a bare remote with `refs/heads/<b>` and
  a decoy `refs/heads/aaa/refs/heads/<b>` at different SHAs, and set local HEAD to the decoy SHA.
  The script must not print PASS. It should also still PASS when HEAD equals the real branch,
  whatever order the lines come in.
- Out of scope per the spec, so don't raise these: the misleading detached-HEAD message and the
  hardcoded `origin` remote.
