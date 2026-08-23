---
name: kxue43-fetch-single-comment
description: "Fetch a single GitHub PR comment by its URL — either a conversation comment (`#issuecomment-<id>` fragment) or an inline review comment (`#discussion_r<id>` fragment) — and load its contents into context, optionally acting on it per given instructions. Use whenever asked to look at, read, or check a specific PR comment by URL."
argument-hint: "<comment-url> [instructions]"
arguments: [comment_url, instructions]
allowed-tools: Bash Read Write Edit Grep Skill mcp__jarvis-registry__discover_servers mcp__jarvis-registry__execute_tool
---

Fetch the GitHub PR comment at `$comment_url` — either a conversation comment (URL fragment
`#issuecomment-<id>`) or an inline review comment (URL fragment `#discussion_r<id>`) — via the
`fetch-single-comment` CLI (not the `jarvis-registry` MCP).

**`$comment_url` is required.** If missing, stop and tell the user before doing anything else.

Run via `Bash`:

```
outfile=$(mktemp)
fetch-single-comment "$comment_url" > "$outfile"
echo "$outfile"
```

`Read` the printed file path. If its content starts with `ERROR:`, stop immediately and report
the error to the user verbatim. Otherwise, the file contains a markdown snippet — the comment's
author (and, for inline review comments, the file path and line it's anchored to) followed by
its body as a block quote. If `$instructions` is provided, follow it using the current session
context and the fetched comment as input. Otherwise, infer the task from the session context and
act on it, using the fetched comment as additional input. If no clearer task is evident, default
to assessing whether the comment raises a legitimate, actionable concern against the current
code, and report a verdict.
