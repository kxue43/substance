---
load:
  - .working-docs/spec/018-skip-skill-ids.md
  - .working-docs/review/018-skip-skill-ids-report.md
base_branch: main
next_labels:
  C: 1
  M: 1
  m: 4
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

## 2026-09-24 — start session (HEAD faa74ac)

- Recommendation: Approve. The implementation is byte-for-byte the spec's code blocks, and every
  behavioral AC was reproduced against a scratch `HOME` (never the real `~/.jarvis-registry/config.yaml`).
- Open: [m1] only. The fix should treat only fzf exit 130 as a cancel and any other non-zero exit as an
  error with exit 1. To verify, put a stub `fzf` that prints to stderr and exits 2 first on `PATH`; the
  script should then exit 1 without touching the config.
- Dismissed: [m2] (preselect-all ignores the current `skip_ids` on a pre-sync re-run) and [m3] (PR
  title typo `skip-skills-id`). Do not re-raise.
- The extra `tartufo.toml` change (skill-ID signature exclusions) is intentional and needed for the
  spec file to pass the pre-commit hook. It is not a finding.
- Test harness used: a python `pty.fork()` driver feeding keys (`\r`, `\x1b`, `\x03`, `\t`, `\x1b[B`)
  to the script, plus `bash --norc -i` in a pty for real TAB completion. Don't run the script from the
  Bash tool without a pty driver: fzf grabs `/dev/tty` and hangs until the timeout.
- The real `~/temp/dump/.github/skills/skill-lock.json` now lists 2 skills (post-sync), so the spec
  AC's "20 IDs" figure can't be reproduced there. Use scratch fixtures.
