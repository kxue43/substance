# Extract SHA Verification into a Reusable `kxue43-verify-sha` Skill

## Background

`kxue43-pr-review/SKILL.md` verifies that the local HEAD matches the PR's remote branch in
two places: `start` Step 3 (line 50) and `followup` Step 3 items 2–4 (lines 235–238). Both currently call
`mcp__jarvis-registry__discover_servers` and then a GitHub API tool to fetch the remote SHA —
leaving a verbose `discover_servers` JSON response and a full PR/ref API object in the context
window solely to compare two 40-character strings. The logic is also duplicated: any future
change to how the check works must be made in two places. This spec extracts the check into a
dedicated `kxue43-verify-sha` skill that uses only the `git` CLI, producing three short
single-line bash outputs instead of API payloads.

---

## Changes

### 1. Create `.claude/skills/kxue43-verify-sha/SKILL.md`

New skill with the following front matter:

```yaml
---
name: kxue43-verify-sha
description: "Verify that local HEAD SHA matches the remote branch SHA using git only."
context: fork
user-invocable: false
allowed-tools: Bash
---
```

`context: fork` runs the skill in an isolated subagent — intermediate `Bash` outputs never
appear in the calling agent's context window; only the single `VERIFY-SHA:` result line is
returned. `user-invocable: false` hides the skill from the slash-command menu since it is
only ever invoked by `kxue43-pr-review`. No arguments — derives the remote branch name from the
local branch, avoiding any GitHub API call or passed-in parameter. The three-step logic:

1. `git rev-parse --abbrev-ref HEAD` → local branch name.
2. `git ls-remote origin refs/heads/<local_branch>` → remote SHA (empty if the ref does not exist).
3. `git rev-parse HEAD` → local HEAD SHA.

Compare: if the remote output is empty, or the two SHAs differ, output **FAIL** with both
values (or note that the remote ref is absent). If they match, output **PASS**.

An empty `git ls-remote` result is treated as a mismatch, not a soft error — if the remote ref
does not exist under the local branch name, the reviewer is on the wrong branch, which is the
correct failure mode for both callers.

The skill outputs exactly one line in one of the following three formats:

```
VERIFY-SHA: PASS
VERIFY-SHA: FAIL — local <40-char SHA> ≠ remote <40-char SHA>
VERIFY-SHA: FAIL — no remote ref found for branch <branch-name>
```

### 2. Modify `kxue43-pr-review/SKILL.md` — add `Skill` to `allowed-tools` (line 7)

`kxue43-pr-review` must be able to invoke `kxue43-verify-sha` via the `Skill` tool.
Add `Skill` to the `allowed-tools` front matter field on line 7.

### 3. Modify `kxue43-pr-review/SKILL.md` — drop "head branch name" from `start` Step 2 (line 47)

The only reason "head branch name" appeared in Step 2's fetch list was to supply the branch
name to Step 3's GitHub API call. With the new skill deriving branch name locally, this field
is no longer needed. Remove it from the bullet on line 47:

> Before: `PR title, description, head branch name, **base branch name**, linked issues, and labels`
> After: `PR title, description, **base branch name**, linked issues, and labels`

**Base branch name is preserved** — it is still required for `git diff origin/<base_branch>...HEAD` in Step 4.

### 4. Modify `kxue43-pr-review/SKILL.md` — replace `start` Step 3 (lines 50–53)

Replace the four-line block with a single skill invocation:

```
3. **Verify the local HEAD matches the PR's remote branch.**
   Invoke the `kxue43-verify-sha` skill. If it returns FAIL, stop immediately. The skill
   reports the mismatch; use `$pr_url` to advise the user which branch to check out or pull
   before proceeding.
```

### 5. Modify `kxue43-pr-review/SKILL.md` — replace `followup` Step 3 items 2–4 (lines 235–238)

Items 2–4 of the current Step 3 validation block discover GitHub tools and fetch the remote
SHA. Replace them with a single skill invocation, keeping item 1 (extract `pr_url`) intact
since `pr_url` is still used in Step 4:

```
1. Extract `pr_url` from the report file's front matter.
2. Invoke the `kxue43-verify-sha` skill. If it returns FAIL, stop immediately. The skill
   reports the mismatch; use `pr_url` from item 1 to advise the user which branch to check
   out or pull before proceeding.
```

---

## What Does NOT Change

- The `followup` subcommand still calls `mcp__jarvis-registry__discover_servers` in Step 4
  to fetch reviewer comments — that call is unaffected and happens later.
- The `start` subcommand still fetches base branch name, PR title, description, labels, and
  review comments in Step 2 via `jarvis-registry`.
- The FAIL behaviour in both callers remains identical: stop immediately and tell the user
  which branch to check out.
- All other steps in both subcommands are unchanged.

---

## Acceptance Criteria

- [ ] `.claude/skills/kxue43-verify-sha/SKILL.md` exists with front matter fields
      `context: fork`, `user-invocable: false`, and `allowed-tools: Bash` (no other tools).
- [ ] Invoking `kxue43-verify-sha` on a branch where local HEAD matches the remote produces
      output starting with `VERIFY-SHA: PASS`.
- [ ] Invoking `kxue43-verify-sha` on a branch where local HEAD does not match the remote
      produces output starting with `VERIFY-SHA: FAIL — local`.
- [ ] Invoking `kxue43-verify-sha` when the local branch name has no matching remote ref
      produces output starting with `VERIFY-SHA: FAIL — no remote ref`.
- [ ] `kxue43-pr-review/SKILL.md` line 7 `allowed-tools` includes `Skill`.
- [ ] `kxue43-pr-review/SKILL.md` `start` Step 2 no longer lists "head branch name".
- [ ] `kxue43-pr-review/SKILL.md` `start` Step 3 contains no reference to `jarvis-registry`
      or GitHub API calls.
- [ ] `kxue43-pr-review/SKILL.md` `followup` Step 3 contains no reference to
      `mcp__jarvis-registry__discover_servers`.

---

## Files to Change

| File | Change |
|---|---|
| `.claude/skills/kxue43-verify-sha/SKILL.md` | **Create.** New skill implementing the three-command git SHA check. |
| `.claude/skills/kxue43-pr-review/SKILL.md` | **Modify.** Four edits: `allowed-tools` (line 7), Step 2 fetch list (line 47), `start` Step 3 (lines 50–53), `followup` Step 3 items 2–4 (lines 235–238). |
