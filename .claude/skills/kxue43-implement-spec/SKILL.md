---
name: kxue43-implement-spec
description: "Implement a spec file on the current branch. Verifies the spec file exists, the current branch is not `main`, and the working tree is clean before implementing; explicitly grants permission to make git commits and use state-mutating git commands during the session."
disable-model-invocation: true
argument-hint: "<spec_path>"
arguments: [spec_path]
allowed-tools: Bash Read Write Edit Grep
---

## Arguments

| Variable | Description |
|----------|-------------|
| `$spec_path` | Path to the spec file to implement — relative to CWD or absolute. |

**`$spec_path` is required.** If missing, stop and tell the user before doing anything else.

## Pre-flight checks

Run all three checks before making any change, in order. Stop at the first failure and report it to the user — do not proceed past a failed check.

1. **Spec file exists.** Run via `Bash`:

   ```
   test -e "$spec_path"
   ```

   If it does not exist, stop immediately and tell the user the spec file was not found at `$spec_path`.

2. **Current branch is not `main`.** Run via `Bash`:

   ```
   git rev-parse --abbrev-ref HEAD
   ```

   If the output is `main`, stop immediately and tell the user this skill refuses to run on `main` — check out a feature branch first.

3. **Working tree is clean.** Run via `Bash`:

   ```
   git status --porcelain
   ```

   If this prints any output (staged or unstaged changes), stop immediately and tell the user the branch has uncommitted changes — commit, stash, or discard them first.

## Implement the spec

If — and only if — all three checks pass:

**You are free to make git commits or use state-mutating git commands (`add`, `commit`, `push`, `branch`, `checkout`, `reset`, `merge`, `rebase`, etc.) for the remainder of this session, as you see fit. This is an intentional and explicit greenlight from the global rule that otherwise reserves state-mutating git operations to the user — it applies here specifically because the pre-flight checks above already confirmed a clean, non-`main` branch to work from.**

Read `$spec_path` with `Read` and implement it in full on the current branch, using `Read`/`Grep`/`Bash` (including `git log`/`git blame` for history and authorship context) to explore the codebase as needed and `Write`/`Edit` to make changes. Commit work at logical checkpoints with clear, descriptive commit messages that explain why. Use your own judgment on how many commits to make and when to make them — do not ask the user for permission before each individual commit.

When implementation is complete, summarize what changed and report the final working tree state to the user.
