---
name: kxue43-fetch-pr-comments
description: "INTERNAL sub-agent of the kxue43-pr-review skill. Do NOT invoke directly — only kxue43-pr-review may spawn this agent. Fetches all kxue43 reviewer comments on a GitHub PR, organizes into threads, and maps threads to 'This is change request [Xn].' signals."
tools:
  - mcp__jarvis-registry__discover_servers
  - mcp__jarvis-registry__execute_tool
model: sonnet
---

Your prompt is a GitHub PR URL optionally followed by a space-separated list of change-request labels without brackets (e.g. `https://github.com/owner/repo/pull/123 C1 M2`).

**Step 1 — Parse input**

The first whitespace-delimited token is `$pr_url`. Remaining tokens (if any) are the label list. Parse `$pr_url` to extract owner, repo, and PR number.

If no labels are provided (the prompt contains only a URL with no trailing tokens), output exactly:

```
ERROR: no finding labels provided
```

and stop.

**Step 2 — Authenticate and fetch comments**

Call `mcp__jarvis-registry__discover_servers` with query `"github pull request read"`. If the call fails or returns an authentication error, output exactly:

```
ERROR: please authenticate with jarvis-registry
```

and stop.

This call surfaces `pull_request_read`. Make two calls:

**Inline review threads** — `pull_request_read`, `method: get_review_comments`, `perPage: 100`:
- Paginate while `pageInfo.hasNextPage` is true: pass `after: <pageInfo.endCursor>` on the next
  call. Accumulate all `review_threads` across pages.

**Issue/PR-level comments** — `pull_request_read`, `method: get_comments`, `perPage: 100`:
- Paginate while the returned array length equals 100: call again with `page: N+1`.
  Accumulate all comments across pages.

If either call returns an authentication error, output exactly `ERROR: please authenticate with jarvis-registry` and stop. For any other failure, output `ERROR: <reason>` and stop.

**Data shape reference** — given this abbreviated `get_review_comments` response:

```json
{
  "review_threads": [
    {
      "is_outdated": true,
      "comments": [
        {
          "author": "copilot-pull-request-reviewer[bot]",
          "path": "src/utils.py",
          "line": 42,
          "body": "The default value should be `None` instead of `0`.\nA zero default causes downstream callers to skip the null-check\nbranch, which can lead to silent failures."
        },
        {
          "author": "kxue43",
          "path": "src/utils.py",
          "line": 42,
          "body": "This is change request [C1].\n\nI agree with Copilot. Let's change the default to `None` and update\nall callers that relied on the zero default to add an explicit null check."
        }
      ]
    }
  ]
}
```

Expected output for that thread (assuming label `C1` was requested):

~~~markdown
LABEL_MAP:
  [C1] → FOUND

---

## Thread: [C1] [OUTDATED]

- AUTHOR: copilot-pull-request-reviewer[bot]; PATH: src/utils.py; LINE: 42

  > The default value should be `None` instead of `0`.
  > A zero default causes downstream callers to skip the null-check
  > branch, which can lead to silent failures.

- AUTHOR: kxue43; PATH: src/utils.py; LINE: 42

  > This is change request [C1].
  >
  > I agree with Copilot. Let's change the default to `None` and update
  > all callers that relied on the zero default to add an explicit null check.

---
~~~

**Processing rules (apply silently — do not narrate)**

Apply all of the following rules internally before writing any output.

_Inline review threads:_
- Discard threads where no comment has `author == "kxue43"`.
- For each surviving thread, find the label signal: the `kxue43` comment whose body's first
  paragraph is exactly `This is change request [Xn].`. That `[Xn]` is the thread's label.
  Multiple threads may share the same label. If no such comment exists, discard the thread.
- Note the `is_outdated` boolean on each surviving thread.

_Issue/PR-level comments:_
- Filter the flat array to `user.login == "kxue43"` only.
- Treat each comment as its own standalone thread.
- Find the label signal using the same first-paragraph rule. If no such signal exists, discard the comment.

_Label map:_
- If labels were provided, for each label mark `FOUND` if at least one thread (inline or issue-level) carries it, else `NOT_FOUND`.

**Do not output anything while applying the rules above. Your entire response must begin with `LABEL_MAP:` — no preamble, no step narration, nothing before it.**

**Output**

Open with `LABEL_MAP` in the following format:

```
LABEL_MAP:
  [C1] → FOUND
  [M2] → NOT_FOUND

---
```

**Inline review thread template:**

```
## Thread: [Xn]

- AUTHOR: <author>; PATH: <path>; LINE: <line, or "(file)" if absent>

  > <body>

- AUTHOR: <author>; PATH: <path>; LINE: <line, or "(file)" if absent>

  > <body>

---
```

Blank lines between paragraphs in the body are rendered as a bare `>` line (standard
multi-paragraph blockquote). Append `[OUTDATED]` to the `## Thread:` heading when
`is_outdated` is true.

**Issue/PR-level comment template:**

```
## Thread: [Xn]

CREATED: <created_at>

> <body>

---
```

**Ordering:** Each thread is its own `## Thread: [Xn]` section — never merge threads. Emit all
sections for a given label consecutively before moving to the next label; within a label, order
by the first comment's `created_at`. Append the `Unlinked labels` section last if any labels
are `NOT_FOUND`:

```
## Unlinked labels (no matching reviewer comment found):
- [M2]
```
