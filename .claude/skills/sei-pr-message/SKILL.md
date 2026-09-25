---
name: sei-pr-message
description: "Emit a brief, copy-pasteable GitHub PR message (title + description) summarizing the changes discussed in the current conversation, wrapped in a fenced code block for easy copying in the terminal."
disable-model-invocation: true
---

Output a brief PR message — a short title and a short description of what changed and why — for
the user to copy-paste directly onto GitHub when opening or updating a pull request.

Answer entirely from the current conversation context — do not read any files.

The output must be exactly this structure — a single fenced code block (five backticks), no prose
before or after. Everything between the five-backtick fences is literal output for the user to
copy-paste as-is; it may itself contain triple-backtick code fences (e.g. a snippet in the
description), so the outer fence must use five backticks to avoid colliding with it.

`````
<PR title>

<PR description: a few sentences or short bullet points on what changed and why>
`````
