# Spec: Fix GitHub data fetching in `kxue43-fetch-pr-comments`

## Context

`kxue43-fetch-pr-comments` was written against the raw GitHub REST API mental model
(`GET /pulls/{n}/comments` → flat list → reconstruct threads via `in_reply_to_id`).
The actual MCP tool (`pull_request_read`) exposes a different shape:

- `get_review_comments` — response is `{ review_threads: [...], pageInfo: { hasNextPage, endCursor } }`.
  Threads are pre-grouped; individual comment objects have `author` (string) and no `in_reply_to_id`.
  Pagination is cursor-based (`after: endCursor`).
- `get_comments` — response is a flat array; author is nested at `user.login`.
  Pagination is page-based (`page: N+1`).

This spec rewrites Steps 1–4 and the output section of `kxue43-fetch-pr-comments` to match the
actual response schema, introduces two distinct output templates (one per source), and renames
`DESCRIPTION` → `PR_MESSAGE` in `kxue43-fetch-pr-data` and the skill.

---

## Changes to `kxue43-fetch-pr-data`

**File**: `.claude/agents/kxue43-fetch-pr-data.md`

### Output format

Rename the key `DESCRIPTION:` to `PR_MESSAGE:`:

```
PR_TITLE: <title>
BASE_BRANCH: <base branch name>
LABELS: <comma-separated label names, or "(none)">

PR_MESSAGE:
<PR body text verbatim>
```

No other changes to this file.

---

## Changes to `kxue43-fetch-pr-comments`

**File**: `.claude/agents/kxue43-fetch-pr-comments.md`

### Step 1 — Parse input

Same as before, with one addition: if no labels are provided (prompt contains only a URL with no
trailing tokens), output exactly:

```
ERROR: no finding labels provided
```

and stop.

### Step 2 — Fetch comments

Call `mcp__jarvis-registry__discover_servers` with query `"github pull request comments"`.
This surfaces `pull_request_read`. Make two calls:

**Inline review threads** — `pull_request_read`, `method: get_review_comments`, `perPage: 100`:
- Paginate while `pageInfo.hasNextPage` is true: pass `after: <pageInfo.endCursor>` on the next
  call. Accumulate all `review_threads` across pages.

**Issue/PR-level comments** — `pull_request_read`, `method: get_comments`, `perPage: 100`:
- Paginate while the returned array length equals 100: call again with `page: N+1`.
  Accumulate all comments across pages.

On failure of either fetch, output `ERROR: <reason>` and stop.

### Step 3 — Inline review thread processing

The API delivers threads pre-grouped — no reconstruction is needed.

1. Iterate over `$.review_threads`. Each entry has a `comments` array and an `is_outdated`
   boolean.
2. Discard threads where no comment has `author == "kxue43"`.
3. For each surviving thread, find the label signal: the `kxue43` comment whose body's first
   paragraph is exactly `This is change request [Xn].`. That `[Xn]` is the thread's label.
   Multiple threads may share the same label. If no such comment exists, the thread is unlabeled.

### Step 4 — Issue/PR-level comment processing

1. Filter the flat array to `user.login == "kxue43"` only.
2. Treat each comment as its own standalone thread.
3. Find the label signal using the same first-paragraph rule.

### Step 5 — Build LABEL_MAP

Unchanged: for each provided label, mark `FOUND` if at least one thread (Step 3 or Step 4)
carries it, else `NOT_FOUND`.

### Step 6 — Output

Open with `LABEL_MAP` (same format as before) if labels were provided, followed by `---`.

**Inline review thread template:**

```
## Thread: [Xn]

- AUTHOR: <author>; PATH: <path>; LINE: <line, or "(file)" if absent>

  > <body>

- AUTHOR: <author>; PATH: <path>; LINE: <line, or "(file)" if absent>

  > <body>

---
```

Blank lines between paragraphs in the body are rendered as a bare `>` line (standard multi-paragraph blockquote).

Append `[OUTDATED]` to the `## Thread:` heading when `is_outdated` is true. Use
`## Thread: (no label signal)` for unlabeled threads.

**Concrete example** — given this abbreviated `get_review_comments` response:

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

Expected rendered output:

~~~markdown
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

**Issue/PR-level comment template:**

```
## Thread: [Xn]

CREATED: <created_at>

> <body>

---
```

Use `## Thread: (no label signal)` for unlabeled threads.

**Ordering:** Each thread is its own `## Thread: [Xn]` section — never merge threads. Emit all
sections for a given label consecutively before moving to the next label; within a label, order
by the first comment's `created_at`. Unlabeled threads follow all labeled sections. Append the
`Unlinked labels` section last if any labels are `NOT_FOUND`.

---

## Changes to `kxue43-pr-review`

**File**: `.claude/skills/kxue43-pr-review/SKILL.md`

### `start` — Step 2

Update the parse line:

> Parse `PR_TITLE`, `BASE_BRANCH`, `LABELS`, and `PR_MESSAGE` (the message written by the PR
> author) from the output.

No other changes to the skill.

---

## Files modified

| File | Change |
|---|---|
| `.claude/agents/kxue43-fetch-pr-data.md` | Rename `DESCRIPTION:` → `PR_MESSAGE:` in output |
| `.claude/agents/kxue43-fetch-pr-comments.md` | Rewrite Steps 1–4 and output templates |
| `.claude/skills/kxue43-pr-review/SKILL.md` | Parse `PR_MESSAGE` in `start` Step 2 |

---

## Verification

1. Run `/kxue43-pr-review start` on a PR with a body. Confirm `PR_MESSAGE` is parsed and used
   in the review evaluation step.
2. Run `/kxue43-pr-review followup` on a PR with inline review threads and known
   `changes_requested` labels. Confirm:
   - `LABEL_MAP` correctly reflects `FOUND`/`NOT_FOUND` per label.
   - Threads with `is_outdated: true` carry `[OUTDATED]` in their heading.
   - Multi-line comment bodies render correctly across paragraphs in the blockquote.
   - No `in_reply_to_id` logic is attempted.
3. Run `/kxue43-pr-review followup` on a session with `changes_requested: []` (all prior
   findings resolved). Confirm the agent returns `ERROR: no finding labels provided` and the
   skill surfaces it — this scenario should not arise in practice (the PR would already be
   merged), but it is the defined behavior.
