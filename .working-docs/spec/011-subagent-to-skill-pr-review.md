# PR Review of the changes from `010-subagent-to-skill.md`

I reviewed the diff, the referenced spec, and the archived subagent definitions this PR replaces. Overall this is a well-scoped, sensible refactor (mechanical "gh-equivalent" fetching moved out of an LLM subagent into a deterministic CLI, with the wrapper skill just relaying stdout). I verified the trickiest part — `gh api --paginate --slurp` — and the `jq 'flatten(1)'` post-processing is correct: `--slurp` wraps each page's array into an outer array (`[[page1...],[page2...]]`), so `flatten(1)` correctly reassembles a flat list of comments. This is actually more robust than the old subagent's manual "page length == 100" pagination heuristic.

That said, I found one real bug and a couple of minor nits.

## Bug — `bin/fetch-pr-data`: unquoted heredoc with untrusted PR body content
```bash
cat <<EOF
PR_TITLE: $title
BASE_BRANCH: $base_branch

PR_MESSAGE:
<pr_message>
$body
</pr_message>
</EOF>
```
Since the heredoc delimiter is unquoted (`<<EOF`, not `<<'EOF'`), two things can go wrong with arbitrary PR body text:
1. **Premature termination:** if the PR description contains a line that is exactly `EOF` (plausible — this very repo is about shell scripting, and code samples/heredoc examples in a PR body could easily include a bare `EOF` line), the heredoc ends early and the rest of the body is silently dropped, truncating exactly the field (`PR_MESSAGE`) this PR was created to fix (the old MCP tool "silently dropping PR body text").
2. **Backslash reinterpretation:** unquoted heredocs get `\`-escape processing like double quotes, so sequences like `` \` ``/`\$`/`\\` in the body can be subtly altered.

Suggest replacing the heredoc with `printf`, which inserts `$body` literally with no re-expansion and no delimiter-collision risk:
```bash
printf 'PR_TITLE: %s\nBASE_BRANCH: %s\n\nPR_MESSAGE:\n<pr_message>\n%s\n</pr_message>\n' \
  "$title" "$base_branch" "$body"
```
(The two `-h` usage heredocs elsewhere use `<<'EOF'` with static content, so they're fine.)

## Minor nits
- **`bin/fetch-pr-comments` jq `num_part` can crash on odd labels.** `tier_rank`/`num_part` assume every label is `[CMm]<digits>`. If a label were purely alphabetic (matches the capture regex `[A-Za-z0-9]+` but has no trailing digits, e.g. a typo'd label), `tonumber` on an empty string throws and the whole script dies with a jq error instead of a graceful `ERROR:` message. Low risk given the established `C1/M2/m3` convention enforced elsewhere, but worth a defensive `tonumber? // 0` if you want it bullet-proof.
- **Temp file leak on unexpected failure.** `stderr_file=$(mktemp)` is cleaned up on the two known failure branches and on success, but under `set -e` an unanticipated failure elsewhere in `main` would skip the `rm -f`. Not a correctness bug, just a minor leak — a `trap 'rm -f "$stderr_file"' EXIT` would be more robust.
- **`archive/` now leaves `.claude/agents/` empty** — harmless (git doesn't track empty dirs), just flagging in case that was unintentional.

## Things that look correct/good
- Pagination via `gh api --paginate` (Link-header driven) is strictly more robust than the old subagent's manual continuation check.
- Multi-comment thread label scanning (`first(... | select(. != null))` over all `kxue43` comments in a thread) matches the PR description's stated behavior.
- `gh pr view --json title,body,baseRefName` — all three are valid JSON fields per `gh` docs.
- `_render_blockquote`'s two-step `sed` correctly reproduces the "bare `>` for blank paragraph lines" blockquote format from the original subagent spec.
- Injection safety is handled properly throughout (`--argjson`/`--args` for jq, no `eval`, no string-built `gh api` queries).
- Wrapper skills correctly downgraded to `haiku` now that they're just "run CLI, relay stdout verbatim" — no LLM judgment needed, consistent with the PR's stated motivation.
- `.claude/CLAUDE.md` softening of the `gh` restriction is precisely scoped ("only inside dedicated skills"), not a blanket re-opening.

**Recommendation:** fix the heredoc issue in `bin/fetch-pr-data` (it directly undermines the PR's core goal of reliably surfacing PR body text); the rest are optional polish.
