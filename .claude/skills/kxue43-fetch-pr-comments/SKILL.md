---
name: kxue43-fetch-pr-comments
description: "INTERNAL skill — invoked only by kxue43-pr-review, do NOT invoke directly. Fetches kxue43-authored reviewer comments on a GitHub PR by delegating to the `fetch-pr-comments` CLI, and reports which of the given finding labels have a matching comment."
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

Use the Bash tool to run this now:

```
outfile=$(mktemp)
fetch-pr-comments $ARGUMENTS > "$outfile"
echo "$outfile"
```

Output the printed path — nothing else — as your entire response.
