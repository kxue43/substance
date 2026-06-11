---
name: kxue43-pr-review
description: "Review a pull request in the ascending-llc/jarvis-registry repository and manage follow-up reviews. Subcommands: `start [pr_url] [spec_file] [report_file] [session_file] [focus_prompt]` runs the initial review; `followup [session_file] [--force-pushed] [focus_prompt]` validates and follows up on a previous review session."
disable-model-invocation: true
argument-hint: "start [pr_url] [spec_file] [report_file] [session_file] [focus_prompt] | followup [session_file] [--force-pushed] [focus_prompt]"
arguments: [subcommand]
allowed-tools: Bash Read Write Edit Grep Skill Agent mcp__jarvis-registry__discover_servers mcp__jarvis-registry__execute_tool
---

## Web Search

If you are uncertain about a library, API, or technology referenced in the PR, discover a web
search tool via `jarvis-registry`:

1. Call `mcp__jarvis-registry__discover_servers` with a concise keyword query (e.g. `"tavily web search"`).
2. Pick the result with the highest relevance score whose description matches a web search tool.
3. Call `mcp__jarvis-registry__execute_tool` with that tool to retrieve current documentation.

Use the results to inform your review rather than guessing at behavior.

---

## Subcommand: `start`

When `$subcommand` is `start`:

### Arguments

| Variable | Description |
|----------|-------------|
| `$pr_url` | Full URL to the GitHub pull request, e.g. `https://github.com/owner/repo/pull/123` |
| `$spec_file` | Path relative to CWD of the spec file describing what the PR should implement and what areas to focus on |
| `$report_file` | Path relative to CWD of the Markdown report file to write |
| `$session_file` | Path relative to CWD of the session manifest file to generate after the review |
| `$focus_prompt` | *(Optional)* Additional instructions for this review. Treat every statement in this prompt as if it were written in **bold** — give it higher focal weight than general review guidelines when the two conflict or compete for attention. |

**The first four arguments are required.** If any are missing, stop and tell the user exactly
which are absent before doing anything else. `$focus_prompt` is optional; if absent, proceed
with standard review behavior.

### Review Process

1. **Read the spec.** Open `$spec_file` with the `Read` tool. Extract the intended behavior,
   acceptance criteria, and any explicitly called-out focus areas. Keep these in mind throughout.

2. **Verify the local HEAD matches the PR's remote branch.**
   Invoke the `kxue43-verify-sha` skill. If its output starts with `VERIFY-SHA: FAIL`, stop
   immediately, relay the output verbatim, and use `$pr_url` to advise the user which branch
   to check out or pull.

3. **Fetch PR data** by invoking the `kxue43-fetch-pr-data` subagent (not jarvis-registry directly), passing `$pr_url` as the
   prompt. If the result starts with `ERROR:`, stop immediately and report the error to the user
   verbatim. Otherwise, parse `PR_TITLE`, `BASE_BRANCH`, and `PR_MESSAGE` (the content inside `<pr_message>…</pr_message>`) from the output.

4. **Collect full diff of all changed files**:
   - Use the base branch obtained from the PR data in Step 3. Run:
     `git diff origin/<base_branch>...HEAD`
   - If the `git` CLI is insufficient (e.g., the remote ref is not available locally), fall back to using GitHub-related tools discovered from the `jarvis-registry` MCP server.

5. **GitNexus impact analysis**: Invoke the `kxue43-gitnexus-analysis` subagent (not
   jarvis-registry directly), passing `origin/<base_branch>` as the prompt (using the base branch
   fetched in Step 3). If the result starts with `ERROR:`, stop immediately and report the error
   to the user verbatim. Otherwise, use the returned digest to guide which symbols and routes to
   focus on in the next step.

6. **Explore local context** using `Bash` (`git log`, `git blame`) and `Read`/`Grep` to understand
   how the changed code fits into the surrounding codebase. Check tests, related modules, and any
   configuration touched by the PR.

7. **Evaluate against the spec:**
   - Does the implementation match the spec's intent and acceptance criteria?
   - Are the focus areas called out in the spec adequately addressed?
   - Are there bugs, missing edge cases, or security concerns?
   - Is code quality acceptable: naming, structure, error handling, test coverage?
   - If anything is unclear due to unfamiliar technology, use web search before concluding.

8. **Do not post any comments to GitHub.** All output goes to `$report_file` only.

### Output Format

Write the following Markdown structure to `$report_file` (create or overwrite):

```markdown
---
description: >
  Front matter tracks which findings have been posted to GitHub as change requests,
  which have been dismissed, and remaining concerns if any.
  changes_requested is a flow sequence of finding labels posted to GitHub that are still open.
  findings_dismissed is a flow sequence of finding labels the reviewer chose not to post.
  merged is a boolean that tracks if the PR has been merged.
  notes is for optional notes about remaining concerns.
pr_url: <actual URL of the PR>
changes_requested: []
findings_dismissed: []
merged:
notes:
---
# PR Review: <PR title>

**PR:** $pr_url
**Spec:** $spec_file
**Reviewed:** <YYYY-MM-DD>

## Summary

<2–4 sentence overall assessment of the PR.>

## Spec Compliance

<For each requirement or focus area in the spec, state: Met / Partially Met / Not Met.
Use a table or bullet list.>

## Findings

Label every individual finding with a short identifier: `[C1]`, `[C2]`, … for Critical;
`[M1]`, `[M2]`, … for Major; `[m1]`, `[m2]`, … for Minor. Use the label as the finding's
bold heading so it can be referenced unambiguously in the front matter.
**Labels are globally unique per PR across all review sessions** — never reuse a label that
appears anywhere in the report file.

### Critical
<!-- Issues that must be resolved before merge -->
<!-- e.g. **[C1] Missing input validation** — … -->

### Major
<!-- Significant concerns that should be addressed -->
<!-- e.g. **[M1] N+1 query in loop** — … -->

### Minor
<!-- Small improvements, nits, suggestions -->
<!-- e.g. **[m1] Inconsistent naming** — … -->

## Positive Observations

<What the PR does well.>

## Recommendation

**<Approve | Request Changes | Needs Discussion>** — <one sentence rationale>.
```

Write the front matter in its **initial state** as shown above: `pr_url` filled with the actual
PR URL, `changes_requested: []`, `findings_dismissed: []`, `merged` and `notes` left empty.

### Post-Report Triage

Immediately after writing the report, walk through every finding with the user one at a time,
in order Critical → Major → Minor.

For each finding, the triage is **strictly binary** — the user must either accept or dismiss it,
no skip option:

1. Present its label and a brief summary.
2. Ask the user: accept (post as a change request) or dismiss?
3. Act on the answer:
   - **Accept:** The user will manually post a PR review comment whose **complete first paragraph**
     reads exactly `This is change request [Xn].` — where `[Xn]` is the finding label. This is
     how Claude links reviewer comments to findings in future `followup` sessions. Add the label
     to the `changes_requested` flow sequence in the report's front matter and save the file
     (e.g. `changes_requested: [C1, M2]`).
   - **Dismiss:** Add the label to the `findings_dismissed` flow sequence in the report's front
     matter and save the file. Rewrite the dismissed finding's body to remove any suggested
     remediation or fix options, keeping only the description of the problem itself. The trimmed
     finding summary **remains in the report body** so that future `followup` sessions can use
     the label and summary to know NOT to re-surface it.
4. Move to the next finding without re-litigating decided ones.

### Session Manifest Generation

After completing Post-Report Triage, compute `next_labels` from the findings you just wrote —
you already know every label assigned. Take the highest-numbered label per severity tier
(e.g. if `[C2]` and `[M1]` appear, C→3, M→2). Use 1 for any tier with no findings.

Write a session manifest file to `$session_file` (create parent directories with `mkdir -p` if needed):

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

# Session Notes

<!--
  `load:` paths are relative to CWD, not to this file.
  The last entry in `load:` is always the report file. All entries before it are spec or
  spec-like files. The user may manually add more spec-like files between sessions, but
  the last entry is always the report file.
  Record prior session conclusions, open questions, and constraints here.
  Write it as a future-you artifact.
-->
```

Then print: `Session manifest written: $session_file`

Do not set `merged` or `notes` in the report's front matter unless the user explicitly asks.

---

## Subcommand: `followup`

When `$subcommand` is `followup`:

### Arguments

| Variable | Description |
|----------|-------------|
| `$session_file` | Path relative to CWD of the session manifest file generated by a previous `/kxue43-pr-review start` run |
| `--force-pushed` | *(Optional boolean flag)* Pass this flag to indicate the PR author performed a force push since the last review session. Must appear before `$focus_prompt` if both are provided. |
| `$focus_prompt` | *(Optional)* Additional instructions for this follow-up. Treat every statement in this prompt as if it were written in **bold** — give it higher focal weight than general review guidelines when the two conflict or compete for attention. |

**`$session_file` is required.** Before doing anything else:
- If the argument is absent, stop and tell the user it is missing.
- If the argument is provided but no file exists at that path, stop and tell the user the file was not found.
Do not proceed past this check in either case.

### Step 1 — Check for Force Push

Before loading anything, check whether the `--force-pushed` flag was passed. If it was:
- Be aware that commit SHAs have changed and the PR branch history has been rewritten.
- GitHub review comments may be marked "outdated" because their target line positions have shifted.
- When fetching new changes, prefer the full current diff rather than relying on incremental commit ranges.
- Keep these considerations active throughout the follow-up review.

### Step 2 — Load Session Context

1. Read the session manifest at `$session_file`. Parse its YAML front matter to extract:
   - `load:` — list of file paths relative to CWD
   - `base_branch:` — the PR's base branch name
2. Read every file listed under `load:`, in order.
   - If any file is missing, **stop immediately** and report which path was not found.
3. Read the markdown body of the session manifest to absorb any prior session notes.
4. The **last entry** in the `load:` list is the **report file** — the single report file used
   throughout all sessions for this PR. All other entries before it are spec or spec-like files.

### Step 3 — Validation

Before doing any review work, verify the PR URL and HEAD commit. If this fails,
**stop immediately and report the failure** to the user before proceeding further.

1. Extract `pr_url` from the report file's front matter.
2. Invoke the `kxue43-verify-sha` skill. If its output starts with `VERIFY-SHA: FAIL`, stop
   immediately, relay the output verbatim, and use `pr_url` from item 1 to advise the user
   which branch to check out or pull.

### Step 4 — Follow-Up Review

Use the loaded spec files and report file to understand the PR's intent, acceptance criteria,
and all findings from previous sessions. If you need to read additional source files, run
`git` commands, or fetch docs to conduct the review, do so freely.

**Pre-review preparation — link reviewer comments to findings:**

1. Extract all finding labels from the `changes_requested` field of the report file's front
   matter. Strip brackets from each label and join with spaces (e.g. `[C1, M2]` → `C1 M2`).
   Invoke the `kxue43-fetch-pr-comments` subagent (not jarvis-registry directly), passing `$pr_url` followed by the label list
   as the prompt. If the result starts with `ERROR:`, stop immediately and report the error to
   the user verbatim. Parse the returned output: `LABEL_MAP` entries show which labels have
   matching reviewer comments (`FOUND`) and which do not (`NOT_FOUND`). Each
   `## Thread: [Xn]` section is a reviewer comment thread for that label; multiple sections with
   the same label are separate threads for the same finding. The thread label matches the finding
   label because the reviewer (kxue43) opens each GitHub comment with a first paragraph of
   exactly `This is change request [Xn].`, echoing back the finding label assigned during triage.
2. If no such comment is found for a label (i.e. `NOT_FOUND` in `LABEL_MAP`), treat that finding
   as **fully unaddressed** by the new code changes. Record this internally — you will issue a
   warning in the Step 5 brief report (do not record it in the report file).
3. **The reviewer's posted comments carry higher weight than the finding summary written by
   Claude Code.** When assessing whether a concern is addressed, prioritize what the reviewer
   actually asked for in their comment over the original finding description.
4. Rate each finding in `changes_requested` as (applies only when a reviewer comment was found;
   findings with no comment are already classified as fully unaddressed per point 2 above):
   - **Addressed:** the reviewer's concern is fully resolved by the new code changes.
   - **Partially addressed:** some but not all of the concern is resolved.
   - **Not addressed:** no substantive changes were made to address the concern.
   - Note: partially addressed counts as **unaddressed** in the session summary. However, the
     finding summary in the report should be **rewritten** to reflect the partial progress.
     Fully unaddressed findings do not need their summary updated.

**Obtain the PR diff:**

Run `git diff origin/<base_branch>...HEAD` using the `base_branch` value parsed from the
session manifest. If the command fails because `origin/<base_branch>` has not been fetched, stop immediately and report the error to the user.

Use this diff as the primary source of changes for all three review tracks below.

**GitNexus impact analysis:** Invoke the `kxue43-gitnexus-analysis` subagent (not
jarvis-registry directly), passing `origin/<base_branch>` as the prompt (using the
`base_branch` value parsed from the session manifest). If the result starts with `ERROR:`,
stop immediately and report the error to the user verbatim. Otherwise, use the returned
digest to inform all three review tracks below.

Perform the following three review tracks **in order, completing each before starting the next**:

1. **Comment resolution:** For each label in the report's `changes_requested`, apply the
   ratings from pre-review preparation above. Do not revisit labels in `findings_dismissed` —
   they were deliberately excluded.

2. **New problems:** Examine the changes introduced since the previous review for any bugs,
   regressions, security issues, or quality problems that did not exist before.

3. **Missed problems:** First write a brief internal handoff: one bullet per label in
   `changes_requested` with its Track 1 rating, plus a one-line note on anything significant
   from Track 2. This is a focusing summary only — you do not need to re-run the diff. Then,
   with fresh eyes and the benefit of the loaded context, check for issues that previous review
   sessions may have overlooked — including areas not directly touched by the latest changes.
   Do not re-surface findings whose labels are in `findings_dismissed`.

### Step 5 — Update

**Make a brief report to the user** covering the three review tracks:
- How well are the requested changes addressed? Include a warning for any label in
  `changes_requested` that had no matching reviewer comment ("`[Xn]` had no matching reviewer
  comment — treated as fully unaddressed").
- Any new problems introduced?
- Any previously missed problems found now?

**If everything is fully addressed and no new problems were surfaced:**

The review is complete. **Do not update the report file or session manifest.** Ask the user
something like "Is there anything else I can do for you?"

**If some findings are not fully addressed, or new problems were surfaced:**

Update the report file and session manifest in place (they are the same files used since the
`start` session). Apply the following changes to the report file:

- **Fully addressed findings:** Remove their label from `changes_requested` and remove their
  finding summary from the report body.
- **Partially addressed findings:** Keep their label in `changes_requested`; rewrite their
  finding summary to reflect the partial progress.
- **Unaddressed findings:** Keep their label in `changes_requested` and keep their finding
  summary unchanged.
- **New problems found in this session:** Use `next_labels` from the session manifest's front
  matter to assign a new, distinct label. Insert the finding summary into the appropriate tier
  section of the report body. **Do not add the label to `changes_requested` yet** — that happens
  during the interactive walk-through below.

Update the session manifest file's front matter:
- Update `next_labels`: for each tier where new findings were assigned, set the value to
  (highest label assigned for that tier) + 1. For tiers where no new findings were assigned,
  carry forward the existing value unchanged.

**Interactive walk-through for new findings:**

If there are no new findings, skip the walk-through and print a summary of what was updated.

Otherwise, walk through every **new** finding one at a time (in order Critical → Major → Minor).
The triage is **strictly binary** — the user must accept or dismiss, no skip option:

1. Present its label and a brief summary.
2. Ask the user: accept (post as a change request) or dismiss?
3. Act on the answer:
   - **Accept:** The user will manually post a PR review comment whose **complete first paragraph**
     reads exactly `This is change request [Xn].`. Add the label to `changes_requested` in the
     report's front matter now and save.
   - **Dismiss:** Add the label to `findings_dismissed` in the report's front matter and save.
     Rewrite the dismissed finding's body to remove any suggested remediation or fix options,
     keeping only the description of the problem itself. The trimmed finding summary remains in
     the report body.
4. Move to the next finding without re-litigating decided ones.

After the walk-through completes, print a summary of what was updated.
