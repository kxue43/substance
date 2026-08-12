---
name: kxue43-fetch-pr-data
description: "INTERNAL wrapper skill of the kxue43-pr-review skill. Do NOT invoke directly — only kxue43-pr-review may invoke this skill. Fetches PR metadata (title, description, base branch) from a GitHub PR URL by delegating to the `fetch-pr-data` CLI."
context: fork
user-invocable: false
allowed-tools: Bash
arguments: [pr_url]
model: haiku
---

Run:

```
fetch-pr-data "$pr_url"
```

Output its stdout **verbatim** as your entire response — no additional commentary, no
reformatting, nothing before or after.
