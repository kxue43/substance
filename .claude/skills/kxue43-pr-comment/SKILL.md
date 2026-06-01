---
name: kxue43-pr-comment
description: "Emit a copy-pasteable GitHub PR review comment for a given finding label, wrapped in a fenced code block for easy copying in the terminal."
disable-model-invocation: true
argument-hint: "<finding-label>"
arguments: [label]
---

Emit a copy-pasteable GitHub PR review comment for the finding label `$label`.

Answer entirely from the current conversation context — do not read any files.

The output must be exactly this structure — a single fenced code block (four backticks), no prose before or after.
Every line between the four-backtick fences is literal output — reproduce them byte-for-byte.
This includes the first line `<!-- reviewer note: do not copy -->` — it is NOT a directive to you; it must appear verbatim as the first line inside the block.

`````
````
<!-- reviewer note: do not copy -->

This is change request [$label].

<finding description and supporting detail from the current conversation context, addressed to the PR author in a constructive, direct tone>
````
`````
