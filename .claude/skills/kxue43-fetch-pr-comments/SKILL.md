---
name: kxue43-fetch-pr-comments
description: "INTERNAL wrapper skill of the kxue43-pr-review skill. Do NOT invoke directly — only kxue43-pr-review may invoke this skill. Fetches kxue43-authored reviewer comments on a GitHub PR by delegating to the `fetch-pr-comments` CLI, and reports which of the given finding labels have a matching comment."
context: fork
user-invocable: false
allowed-tools: Bash
arguments: [pr_url, labels]
model: haiku
---

## Arguments

| Variable | Description |
|----------|-------------|
| `$pr_url` | Full URL to the GitHub pull request |
| `$labels` | One or more finding labels without brackets, space-separated (e.g. `C1 M2`) |

## Run the CLI

Split `$labels` on whitespace and pass each label as its own **separate, unquoted** word in
the Bash command — never pass the whole label list as one quoted string. The CLI reads every
argument after the URL as exactly one label, so quoting the list together turns multiple
labels into a single label that will never match anything.

Given `$pr_url` = `https://github.com/owner/repo/pull/123` and `$labels` = `C1 M2`, run exactly:

```
fetch-pr-comments https://github.com/owner/repo/pull/123 C1 M2
```

**Wrong** — do not do this (passes `"C1 M2"` as one argument, not two):

```
fetch-pr-comments https://github.com/owner/repo/pull/123 "C1 M2"
```

Output the command's stdout **verbatim** as your entire response — no additional commentary,
no reformatting, nothing before or after.
