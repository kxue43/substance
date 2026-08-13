# Wrapper Skill Improvements

Scope: `kxue43-fetch-pr-comments`, `kxue43-fetch-pr-data`, and their caller `kxue43-pr-review`
(all under `~/.config/substance/.claude/skills/`). `kxue43-verify-sha` is out of scope — same
`context: fork` + verbatim-echo shape, but its payload is a one-line status; the file-handoff
round-trip below isn't worth it there.

## Finding 1 — multi-token `$labels` silently truncated

Reproduction: invoking `Skill(skill: "kxue43-fetch-pr-comments", args: "<pr_url> C1 C2 C3")`
against `arguments: [pr_url, labels]` delivered the fork only:

```
| `<pr_url>` | Full URL to the GitHub pull request |
| `C1`       | One or more finding labels without brackets, space-separated (e.g. `C1 M2`) |
```

`C2` and `C3` never reached the fork. The Skill-invocation layer maps the single `args` string
onto `arguments: [name1, name2, ...]` by splitting on whitespace and zipping one token per
declared name — tokens past the last name are dropped, not folded into it. This is live in
production: `kxue43-pr-review`'s `followup` subcommand (SKILL.md line ~252) builds this exact
call — `changes_requested: [C1, M2]` → join with spaces → invoke `kxue43-fetch-pr-comments`.
Any report with more than one open finding silently loses labels past the first, and those
labels are absent from `LABEL_MAP` entirely (not even `NOT_FOUND`).

**Fix — drop `arguments:` entirely; read `$ARGUMENTS` instead.**

`arguments: [...]` has no rest-param/vararg syntax — confirmed against the official docs
(`code.claude.com/docs/en/skills.md`, frontmatter reference, line 330): names map to positions
1:1 by whitespace-split, and there is no way to make the last declared name absorb the rest.
That part of the original diagnosis stands.

But `$ARGUMENTS` is a separate, independently-available placeholder that always expands to the
**full raw args string as typed** (skills.md line 419), regardless of whether `arguments:` is
declared at all — three of the docs' own example skills (`session-logger`, `deploy`,
`deep-research`; lines 427–436, 479, 717–722) use `$ARGUMENTS` with no `arguments:` key
whatsoever. Since the CLI's own positional signature is `fetch-pr-comments <pr_url> [label...]`
— URL first, then space-separated labels, exactly the token order `$ARGUMENTS` already has — no
parsing/splitting is needed. Pass it straight through, unquoted.

`kxue43-fetch-pr-comments/SKILL.md`: remove the `arguments:` frontmatter key entirely, remove
the `## Arguments` table, and replace the CLI invocation with `fetch-pr-comments $ARGUMENTS`
(full replacement body shown in Finding 2, which layers the temp-file fix from that finding on
top of this one — the two land as a single combined edit to the same section).

`kxue43-pr-review/SKILL.md` line ~252: **no change.** Keep space-joining the label list
(`C1 M2`) as it already does — the comma round-trip is no longer needed on either side.

No change needed to `kxue43-fetch-pr-data` (single-argument skill, not exposed to this bug;
`arguments: [pr_url]` already captures its one argument correctly).

## Finding 2 — verbatim-echo forces full output regeneration

Measured on a `kxue43-fetch-pr-comments` run (haiku fork, 1554 output tokens of CLI stdout):

| Phase | Duration |
|---|---|
| Fork startup (skill-context cache creation, 15.5k tokens) | ~3.1s |
| Actual `fetch-pr-comments` Bash call | ~2.1s |
| Model turn overhead before final answer | ~2.0s |
| Model generating the final answer (regenerating CLI stdout verbatim) | ~21.4s |

A fork's return value to its caller is always its final assistant-text message — there is no
channel for a `tool_result` to reach the caller without an LLM regenerating it token-by-token.
The `verbatim` instruction in both wrapper skills forces exactly that regeneration, and it
dominates wall-clock time in proportion to output size.

**Fix — write CLI stdout to a temp file, return only the path.**

A fork's return value to its caller is always its final assistant-text message, and that
message only ever reaches the caller's context — the fork's own tool calls (including the raw
`Bash` stdout) never do, whether or not the output is echoed. Confirmed against
`code.claude.com/docs/en/sub-agents.md` (lines 262, 298, 1017, 1061): a fork with no
`isolation:` override "starts in the main conversation's current working directory" and shares
its filesystem by default — `isolation: worktree` (unused here) is what would sandbox it. So a
temp file the fork writes via `mktemp` is on the same filesystem the caller already sees, and
the caller's later `Read` of that path is guaranteed to resolve.

`kxue43-fetch-pr-comments/SKILL.md`, replace the final `Output the command's stdout verbatim...`
line (this supersedes the `## Run the CLI` snippet from Finding 1 — the two combine into one
step):

```markdown
## Run the CLI

`$ARGUMENTS` expands to the full argument string as typed: the PR URL followed by zero or more
finding labels, space-separated (e.g. `https://github.com/owner/repo/pull/123 C1 M2`). This
already matches the CLI's own positional signature token-for-token, so pass it straight through
**unquoted** — wrapping it in quotes would collapse the whole thing into a single argument and
break label matching.

Redirect stdout to a temp file instead of printing it, and return only the file's path:

    outfile=$(mktemp)
    fetch-pr-comments $ARGUMENTS > "$outfile"

Output `$outfile` — nothing else — as your entire response.
```

`kxue43-fetch-pr-data/SKILL.md`, same treatment:

```markdown
Redirect stdout to a temp file instead of printing it, and return only the file's path:

    outfile=$(mktemp)
    fetch-pr-data "$pr_url" > "$outfile"

Output `$outfile` — nothing else — as your entire response.
```

**Caller-side change required in `kxue43-pr-review/SKILL.md`** — both skills now return a path,
not payload text; every call site must `Read` it before checking for `ERROR:` or parsing.

Step 3 of `start` (lines ~51–53):

```markdown
3. **Fetch PR data** by invoking the `kxue43-fetch-pr-data` skill (not jarvis-registry directly),
   passing `$pr_url` as its argument. The skill returns a file path — `Read` that file. If its
   content starts with `ERROR:`, stop immediately and report the error to the user verbatim.
   Otherwise, parse `PR_TITLE`, `BASE_BRANCH`, and `PR_MESSAGE` (the content inside
   `<pr_message>…</pr_message>`) from the file's content.
```

Pre-review preparation of `followup` (lines ~253–256):

```markdown
Invoke the `kxue43-fetch-pr-comments` skill (not jarvis-registry directly), passing `$pr_url`
followed by the space-joined label list as its arguments.
The skill returns a file path — `Read` that file. If its content starts with `ERROR:`, stop
immediately and report the error to the user verbatim. Parse the file's content: `LABEL_MAP`
entries show which labels have matching reviewer comments (`FOUND`) and which do not
(`NOT_FOUND`)...
```

(Remainder of that paragraph — thread-label matching rules — is unchanged, only the source of
the text moves from "the returned output" to "the file's content.")

`kxue43-pr-review` already has `Read` in `allowed-tools`, so no permission change is needed.

## Decision — keep `context: fork` despite the shrunk body

With both fixes applied, `kxue43-fetch-pr-comments/SKILL.md`'s body drops to a few lines, which
raised the question of whether forking is still worth its fixed startup cost (~3.1s / 15.5k
tokens, per the Finding 2 table). It is — for two reasons unrelated to body size:

1. **`model:` behaves differently in vs. out of a fork.** Per skills.md line 335: `model:`
   "overrides the session model for the rest of the current turn... **with `context: fork`, the
   value sets the forked subagent's model instead**." Dropping the fork while keeping
   `model: haiku` would downgrade `kxue43-pr-review`'s *own* model for the rest of that turn —
   degrading whatever review reasoning the orchestrator does afterward. Inlining safely would
   require dropping `model: haiku` too, losing the cheap/fast execution for this step.
2. **The docs pick fork vs. inline by task shape, not line count.** Lines 273/287: "reference
   content runs inline" vs. task content — "step-by-step instructions for a specific action" —
   should use `context: fork`. A skill with a fixed input contract and one return value (a file
   path) is the "specific action" case regardless of how few lines it takes to say so; the fork
   is also what makes "return only the path" a meaningful contract in the first place (the
   fork's final message *is* the return value — inlined, there's no such boundary).

(`allowed-tools:` does apply to inline skills too, per line 333 — tool-scoping alone isn't a
reason to fork. The `model:` behavior and the task/reference framing are.)
