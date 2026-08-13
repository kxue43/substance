---
name: kxue43-fetch-pr-comments
description: "INTERNAL wrapper skill of the kxue43-pr-review skill. Do NOT invoke directly — only kxue43-pr-review may invoke this skill. Fetches kxue43-authored reviewer comments on a GitHub PR by delegating to the `fetch-pr-comments` CLI, and reports which of the given finding labels have a matching comment."
context: fork
user-invocable: false
allowed-tools: Bash
model: haiku
---

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
