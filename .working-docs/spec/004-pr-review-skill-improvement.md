# Reduce Context Pollution in `kxue43-pr-review` — Three Targeted Improvements

## Background

`kxue43-pr-review/SKILL.md` has three inefficiencies that load more into the context window
than the review requires. First, the `start` subcommand fetches existing review comments it
has no use for. Second, the session manifest records no base branch name, so `followup` would
need an extra API call to determine it. Third, `followup` has no stated preference between
`git` CLI and GitHub API when obtaining the PR diff, leaving the model free to pick the
heavier-weight API path. The three improvements are implemented as four edits to a single
file. They do not depend on and do not conflict with the changes in spec `003`.

---

## Changes

### 1. Drop "Existing review comments and inline discussions" from `start` Step 2 (line 48)

Remove the second bullet from `start` Step 2's fetch list:

```
- Existing review comments and inline discussions   ← delete this line
```

**Why:** In a `start` session, no change-request comments exist yet — the `start` subcommand
is what produces the findings that the user later posts as comments. Fetching review threads at
this point returns data that serves no step in the `start` workflow; it adds at least one
`pull_request_read` API call whose response (full thread objects with position metadata and
comment bodies) lands in context unused. The spec file is the intended source of review intent;
PR discussion threads are not.

### 2. Record `base_branch` in the session manifest (lines 168–189 and line 222)

Two edits implement this improvement.

**2a. Add `base_branch` to the session manifest template (lines 168–189)**

Add a `base_branch` field to the YAML front matter block of the session manifest template,
between the `load:` block and `next_labels:`:

```
---
load:
  - <$spec_file — path relative to CWD>
  - <$report_file — path relative to CWD>
base_branch: <base branch name fetched in Step 2>
next_labels:
  C: <computed next Critical number>
  M: <computed next Major number>
  m: <computed next minor number>
---
```

**Why:** `followup` needs the base branch name to run `git diff origin/<base_branch>...HEAD`
(Change 3 below). The base branch is already available during `start` Step 2's GitHub API
fetch; storing it in the manifest makes `followup` self-contained without an additional API
call.

**2b. Parse `base_branch` in `followup` Step 2 (line 222)**

In `followup` Step 2 item 1, extend the list of fields parsed from the session manifest front
matter to include `base_branch`:

```
1. Read the session manifest at `$session_file`. Parse its YAML front matter to extract:
   - `load:` — list of file paths relative to CWD
   - `base_branch:` — the PR's base branch name
```

**Why:** Makes the `base_branch` value explicitly available as a named variable for the diff
command in Change 3 below.

### 3. Add diff acquisition preamble to `followup` Step 4 (before line 269)

Insert the following block immediately before the "Perform the following three review tracks"
line (currently line 269), as a named step between the pre-review preparation block and the
three tracks:

```
**Obtain the PR diff:**

Run `git diff origin/<base_branch>...HEAD` using the `base_branch` value parsed from the
session manifest. Prefer the `git` CLI over `pull_request_read get_diff` — the git output
enters context as plain text with no API wrapper overhead. Fall back to
`pull_request_read get_diff` only if the remote ref is not available locally.

Use this diff as the primary source of changes for all three review tracks below.
```

**Why:** Without explicit guidance, the model may call `pull_request_read get_diff`, which
wraps the same diff content in a larger API response object. The three-dot form
`origin/<base_branch>...HEAD` is correct for all cases — including after a force-push —
because it computes the diff from the merge base rather than relying on commit history shape.
A single diff command serves all three tracks; there is no need for an incremental diff
because the loaded report file already documents all prior findings, giving the model the
context to avoid re-flagging already-reviewed code.

---

## What Does NOT Change

- The comment-fetching logic in `followup` Step 4 pre-review preparation is unchanged —
  fetching all review threads to find labeled comments is necessary and has no git-CLI
  equivalent.
- All other fields in the session manifest (`load`, `next_labels`) are unchanged.
- The `start` Step 2 still fetches PR title, description, base branch name, labels, and
  linked issues via GitHub API.
- Nothing in `followup` Steps 1, 3, or 5 changes.

---

## Acceptance Criteria

- [ ] `start` Step 2 in `kxue43-pr-review/SKILL.md` contains no mention of review comments
      or inline discussions.
- [ ] The session manifest template in `kxue43-pr-review/SKILL.md` includes a `base_branch:`
      field populated with the base branch name from Step 2.
- [ ] `followup` Step 2 item 1 lists `base_branch:` alongside `load:` as a field to parse
      from the session manifest front matter.
- [ ] `followup` Step 4 contains explicit guidance to run `git diff origin/<base_branch>...HEAD`
      before the three review tracks, with a stated preference for git CLI over the GitHub API.
- [ ] `followup` Step 4 guidance names `base_branch` as coming from the session manifest.
- [ ] `followup` Step 4 guidance covers the force-push case without requiring a separate code
      path (three-dot diff is correct for both).

---

## Files to Change

| File | Change |
|---|---|
| `.claude/skills/kxue43-pr-review/SKILL.md` | Four edits across three improvements: drop line 48 (improvement 1); extend session manifest template (lines 168–189) and `followup` Step 2 item 1 (line 222) to record and parse `base_branch` (improvement 2); insert diff preamble before line 269 (improvement 3). |
