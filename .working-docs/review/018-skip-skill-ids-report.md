---
description: >
  Front matter tracks which findings have been posted to GitHub as change requests,
  which have been dismissed, and remaining concerns if any.
  changes_requested is a flow sequence of finding labels posted to GitHub that are still open.
  findings_dismissed is a flow sequence of finding labels the reviewer chose not to post.
  merged is a boolean that tracks if the PR has been merged.
  notes is for optional notes about remaining concerns.
pr_url: https://github.com/kxue43/substance/pull/25
changes_requested: [m1]
findings_dismissed: [m2, m3]
merged:
notes:
---
# PR Review: Feature: `skip-skills-id` command

**PR:** https://github.com/kxue43/substance/pull/25
**Spec:** .working-docs/spec/018-skip-skill-ids.md
**Reviewed:** 2026-09-24

## Summary

`bin/skip-skill-ids` and `completions/skip-skill-ids` match the spec's code blocks exactly. Both follow
the repo's `bin/` template, completion namespacing, and heredoc conventions. Every behavioral acceptance
criterion was reproduced against a scratch `HOME`, with the fzf UI driven through a real pty: the merge
semantics, the zero-selection guard, Esc and Ctrl-C, numeric-ID quoting, comment and indentation
preservation, symlink and file-mode preservation, and completion, including no filename fallback in a
real `bash -i`. The remaining findings are minor: fzf failures are reported as a user cancel, the
preselection ignores the current config state, and the PR title has a typo.

## Spec Compliance

| Requirement / AC | Status | Notes |
|---|---|---|
| `bin/skip-skill-ids` follows `bin/` template, single command, `-h` only help | Met | Code is identical to the spec block |
| Arg check: exactly one arg, otherwise exit 1 with exact message | Met | 0 and 2 args print `skip-skill-ids requires exactly one argument SKILL_LOCK_FILE.`, rc=1 |
| Lock validation (nonexistent, non-JSON, `{"skills":{}}`, top-level array) exits 1, config byte-identical | Met | `cmp` clean |
| `{"skills":[]}` exits 0 with `No skills listed in …` | Met | |
| Missing `config.yaml` exits 1 with `Run 'jarvis-registry configure' first.`, file not created | Met | |
| fzf shows names only, all preselected; `--accept-nth=1` returns bare IDs | Met | `--filter` mode output has no trailing tab (`od -c`) |
| Default Enter appends lock IDs after existing non-lock IDs, which are kept | Met | Verified on scratch fixture; the real `~/temp/dump` lock now lists 2 skills post-sync, so the "20 IDs" figure is a historical state |
| Deselecting an ID already in `skip_ids` removes it; non-lock IDs kept | Met | |
| Deselect-all + Enter / Esc / Ctrl-C → `Nothing selected. … unchanged.`, exit 0, byte-identical | Met | See [m1] for non-user fzf exits taking the same path |
| Numeric-looking IDs quoted; `jarvis-registry skills show` parses them | Met | `"123456789012345678901234"`, `"600000000000000000000e12"`; CLI 0.6.6 lists both |
| Comment survives; 4-space indentation kept | Met | Inline comment on a surviving item also preserved |
| Symlinked config stays a symlink; file mode preserved | Met | `0600` target kept |
| Completion from `~/temp/dump`, `.github/skills`, and a lock-less dir; `-h`; no second-arg / no filename fallback | Met | Real interactive bash TAB rang the bell with no filenames offered |
| `shellcheck` / `shfmt -i 2 -d` clean | Met | |
| `.keep` bumped | Met | |
| Files to Change | Met (+1) | `tartufo.toml` additionally excludes the spec's skill-ID signatures. This isn't in the spec but is required for the tartufo pre-commit hook to pass on the spec file |

## Findings

### Critical

_None._

### Major

_None._

### Minor

**[m1] fzf errors are reported as a user cancel and exit 0** — `bin/skip-skill-ids:67-76` treats *any*
non-zero fzf exit as "Nothing selected". fzf returns 130 for Esc, Ctrl-C and the guarded `abort`, but 2
for an error, e.g. an fzf older than 0.60 rejecting `--accept-nth`, fzf < 0.51 rejecting `--with-shell`,
or no usable `/dev/tty`. Reproduced with a stub `fzf` that prints `unknown option: --accept-nth=1` and
exits 2. The script then printed `Nothing selected. … unchanged.` and exited **0**. No write happens, so
the failure is safe, but the message misreports a hard error as a deliberate choice and the exit status
hides it. That matters because `bin/` is symlinked on every clone, including the fedora and devcontainer
environments, where distro fzf builds can be older than Homebrew's 0.74. Suggested fix: capture the exit
code (`selected="$(fzf …)" || rc=$?`). Keep the info message for `rc == 130`. For any other non-zero code,
`kxue43::log_error "fzf failed (exit $rc). $config_file unchanged."` and `return 1`.

**[m2] Preselection ignores the current `skip_ids`, so a re-run before sync re-skips kept skills** —
`--bind 'load:select-all'` always preselects every row. After a `skills sync`, that is exactly right: the
lock file lists only non-skipped skills. If the script is re-run on the same lock file *before* syncing,
the skills the user deliberately deselected last time show as selected again. The AC "deselecting a skill
whose ID was already in `skip_ids` removes that ID" covers the reverse case. Pressing Enter, or making one
unrelated change and pressing Enter, silently turns those kept skills into skips. The UI's starting state
therefore doesn't reflect the config in the one case where the merge logic actually reads it.

**[m3] PR title misnames the command** — The title reads ``Feature: `skip-skills-id` command``. The
script is `skip-skill-ids`. This repo squash-merges with the PR title as the commit subject (e.g. `7b3aa0d
Feature: Move … (#24)`), so the wrong name would land in `main`'s history and in `git log --grep`
results.

## Positive Observations

- The merge formula `(existing // []) − lock_ids + selected` is correct, idempotent across re-runs, and
  preserves non-lock IDs in their original order. The spec's reasoning about the CLI never writing
  skipped skills to the lock file carries straight through to the code comment.
- The zero-selection `enter` guard closes a real fzf `-m` quirk. `--with-shell 'bash -c'` pins the
  `((…))` arithmetic, so the guard doesn't depend on `$SHELL`.
- `strenv(...) | split("\n")` keeps IDs as `!!str`. yq quotes numeric-looking values, and the CLI parses
  them correctly.
- The single `jq -e` shape check rejects invalid JSON, a missing or object `.skills`, non-object elements,
  and a top-level array before anything touches the config. Every abort path exits before yq runs.
- Completion avoids `-o default`, so it offers exactly the CLI's lock-file locations and never floods
  the prompt with filenames.

## Recommendation

**Approve** — the implementation fully meets the spec and was verified end to end. The three minor
findings are a robustness edge ([m1]), a UX edge in the re-run-before-sync flow ([m2]), and a title
typo ([m3]), and none of them risk corrupting the config.
