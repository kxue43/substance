# Simplify the kxue43-pr-review Skill

**IMPORTANT: Claude Code is absolutely NOT allowed to read or write any files outside of the CWD!**
**The three Claude Code skill files under discussion below are all located in the `.claude/` folder of CWD.**
**They are symlinked to from the user's home directory, so updating them is sufficient to update the skill files for the user.**

## Overview

I recently decided to adopt a spec-based, narrowly scoped, session by session workflow pattern
when using Claude Code CLI.

Previously you developed the `.claude/skills/kxue43-pr-review/SKILL.md` skill for me from my spec file,
to implement this spec and session based workflow specifically for the process of PR reviews.
Now I realized that this skill is too complex because it tries to be too stateful.
This spec is about simplifying the skill.

The major complexity are at the following places.
- In a multi-session followup process of a PR review, it generates one report for the `start` session
  and one for each `followup` session. The session manifest file references all reports.
  This causes the finding summaries of resolved problems to be loaded into the context window of a new session,
  defeating the purpose.
- This problem is intrinsically stateful, but the cross-session state management is too complex.

There are also minor ambiguity at the following places.
- The pattern is that Claude Code generates report files only, and the human user manually posts comments
  for findings that he accepts. This is not stated clearly enough.
- There is no established pattern to connect user's manually posted comments with the findings listed by Claude Code.
- The user's manually posted review comments has higher priority than Claude Code's finding summary,
  when deciding whether the comment is properly addressed by new changes. This is not stated clearly enough.

## CHANGE REQUESTS

Make the following changes to simplify the process.

- We use one report file throughout, and update it across sessions. Updates are git tracked.

- After the `start` subcommand, we generate a session manifest file, and later update and use this same session manifest file
  throughout all `followup` sessions.

- The `start` subcommand is largely the same as before, with the following additions and changes.
  * The report front matter drops `changes_resolved` entirely. It is no longer a field.
  * A new flow-style array field `findings_dismissed: []` is added to the report's initial front matter.
  * The `load` field in the session manifest's front matter lists the only report file at the end of the array.
    Before the report file path, there could be multiple spec and spec-like files, but there's only one report
    and it's always last. The user may manually add more spec-like files into `load` between sessions; the
    guarantee is that there is at least one spec file and the last entry is always the report file.
  * The `next_labels` field stays and is derived the same as before.
  * The post-report triage is now strictly binary: each finding must be either **accepted** or **dismissed** —
    there is no skip option.
    - When user accepts a finding, e.g. a finding labeled with `[C1]`, he will post a PR review comment whose
      first paragraph is `This is change request [C1].`. **Complete first paragraph. Label inside square brackets
      at the end.** This is how Claude links user's comments with its findings in `followup` sessions later.
      Add the label to `changes_requested`.
    - When user dismisses a finding, add its label to `findings_dismissed` in the report's front matter.
      The dismissed finding's summary remains in the report body. In `followup` sessions, Claude uses the labels
      in `findings_dismissed` and the finding summary to know NOT to re-surface a dismissed finding.

- The `followup` subcommand should be simplified like below.
  * Adds an optional boolean flag `--force-pushed`, which indicates if there's a force push from the PR author,
    instead of learning that from `$focus_prompt`.
  * Step 1 is the same, except force push is learned from the new flag.
  * Step 2 largely the same, except that point 4 stresses that the last entry in `load` is the only report file,
    and all others are spec or spec-like files.
  * Step 3, only keep validation A. Drop validation B entirely. The human user will make sure he posts comments
    conscientiously.
  * Step 4, review process is the same, except that we should add the following things regarding pre-review
    preparation.
    - Extract finding labels from the `changes_requested` field of the report front matter.
    - With each such label, locate the reviewer's comments that start with `This is change request [<label>].`,
      and look at the thread of conversation between the reviewer and the PR author.
    - If the reviewer didn't post any such comment, treat the finding as fully unaddressed by the new code
      changes. Issue a warning in the Step 5 brief report only (do not record it in the report file).
    - The reviewer's comments have higher weight than the finding summary written by Claude Code.
      Review if the comment is fully addressed, partially addressed, or not addressed.
    - Partially addressed counts as unaddressed in the session's summary, except that the finding summary
      should be re-written to take the partial changes into consideration. Fully unaddressed items don't need
      updating the finding summary.
  * Step 5 has the following changes.
    - The brief report covering three review tracks is the same, except to include the warning for any labels
      in `changes_requested` that had no matching reviewer comment.
    - If everything is fully addressed and there is no new problem surfaced, the review is completed and
      **do not update the report file**. Ask the user something like "are there anything else I can do for you".
    - If some findings are not fully addressed, or new problems surfaced, do the following.
      * For fully addressed findings, remove their label from `changes_requested` and remove their finding
        summary from the report body.
      * Partially addressed: keep label in `changes_requested` and update finding summary accordingly.
      * For unaddressed: keep label and keep finding summary unchanged.
      * For new problems, use `next_labels` from the session manifest file to assign a new, distinct label,
        insert finding summary into the report file, but don't add label to `changes_requested` yet.
      * Update `next_labels` in the session manifest file's front matter. For tiers where new findings were
        assigned, set to (highest label assigned for that tier) + 1; for tiers where no new findings were
        assigned, carry forward the existing value unchanged.
      * Use `git add` to add both the updated report file and session manifest file into the Git staging area.
      * Now come back to walk through all **new** findings interactively with the user. The triage is strictly
        binary — each finding must be accepted or dismissed, no skip option.
        If user accepts, he will manually post a comment with the same first paragraph. Add the label to
        `changes_requested` now.
        If user dismisses, add label to `findings_dismissed`. This part is similar to the interactive
        walk-through in the `start` subcommand.
      * After the walk-through, `git add` both the updated report file and session manifest file,
        **commit now with Claude Code as co-author**.
