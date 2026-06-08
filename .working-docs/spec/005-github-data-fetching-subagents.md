# Spec: Extract GitHub data fetching from `kxue43-pr-review` into subagents

## Context

`kxue43-pr-review` previously performed GitHub data fetching inline — `discover_servers` →
`execute_tool` — at two points:

1. **`start` Step 2**: fetch PR title, description, base branch, labels.
2. **`followup` Step 4 (pre-review preparation)**: fetch reviewer comments, build threads,
   identify `This is change request [Xn].` signals.

Named subagents (`~/.claude/agents/`) isolate this work: their tool calls and raw API responses
live in a separate context window; only the final result text returns to the parent.

---

## Subagent 1 — `kxue43-fetch-pr-data`

**File**: `.claude/agents/kxue43-fetch-pr-data.md`

**Front matter**:
```yaml
name: kxue43-fetch-pr-data
description: "Fetch PR metadata (title, description, base branch, labels) from a GitHub PR URL and return a clean structured summary."
tools:
  - mcp__jarvis-registry__discover_servers
  - mcp__jarvis-registry__execute_tool
model: haiku
```

**Input**: `$pr_url` as the prompt.

**Process**:
1. `discover_servers "github pull request read"` → pick highest-relevance result.
2. `execute_tool` to fetch the PR.
3. Extract: title, body, base branch, labels.

**Success output** (nothing else):
```
PR_TITLE: <title>
BASE_BRANCH: <base branch name>
LABELS: <comma-separated label names, or "(none)">

DESCRIPTION:
<PR body text verbatim>
```

**Failure output**:
```
ERROR: <reason>
```

---

## Subagent 2 — `kxue43-fetch-pr-comments`

**File**: `.claude/agents/kxue43-fetch-pr-comments.md`

**Front matter**:
```yaml
name: kxue43-fetch-pr-comments
description: "Fetch all kxue43 reviewer comments on a GitHub PR, organize into threads, and map threads to 'This is change request [Xn].' label signals."
tools:
  - mcp__jarvis-registry__discover_servers
  - mcp__jarvis-registry__execute_tool
model: sonnet
```

**Input**: `$pr_url` followed by an optional space-separated list of labels without brackets
(e.g. `https://github.com/owner/repo/pull/123 C1 M2`).

**Process**:

1. Parse `$pr_url` (owner, repo, PR number) and label list.

2. `discover_servers "github pull request comments"`. Fetch from two endpoints only:
   - **Inline review comments**: `GET /repos/{owner}/{repo}/pulls/{pull_number}/comments`
   - **Issue/PR comments**: `GET /repos/{owner}/{repo}/issues/{issue_number}/comments`

   Paginate each if indicated (`next` link or per-page count equals maximum). On failure, output
   `ERROR: <reason>` and stop.

   The `/pulls/{pull_number}/reviews` endpoint is intentionally excluded — this reviewer does not
   use review-level body comments.

3. **Inline review comment thread reconstruction**:
   - Root = comment with no `in_reply_to_id`. Each reply belongs to the thread of whatever
     comment its `in_reply_to_id` points to (follow chain to root).
   - Discard threads with no `kxue43` comment anywhere.
   - Retain the full thread (all authors) in chronological order.
   - Label signal: find the `kxue43` comment whose first paragraph is exactly
     `This is change request [Xn].`. That `[Xn]` is the thread's label. Multiple threads may
     carry the same label (one change request touching multiple code locations). If no such
     comment exists, the thread is unlabeled.

4. **Issue/PR comment threads**: filter to `login == "kxue43"`. Each comment is its own thread.
   Apply the same label-signal rule.

5. **LABEL_MAP**: if labels were provided, mark each `FOUND` (≥1 thread carries it) or
   `NOT_FOUND`.

**Success output** (nothing else):

```
LABEL_MAP:
  [C1] → FOUND
  [M2] → NOT_FOUND

---

## Thread: [C1]

**<login>** (review comment, <file>:<line>, <date>):
> <comment body>

  **<login>** (review comment, <file>:<line>, <date>):
  > <reply body>

---

## Thread: [C1]

**<login>** (review comment, <file>:<line>, <date>):
> <bot comment that preceded the signal>

**kxue43** (review comment, <file>:<line>, <date>):
> This is change request [C1].
>
> <rest of comment body>

---

## Thread: (no label signal)

**kxue43** (top-level comment, <date>):
> <comment body>

---

## Unlinked labels (no matching reviewer comment found):
- [M2]
```

Multiple `## Thread: [Xn]` sections with the same label are emitted when the same label appears
in separate threads. Omit `LABEL_MAP` and `Unlinked labels` when no labels were provided.

**Failure output**:
```
ERROR: <reason>
```

---

## Changes to `kxue43-pr-review`

**File**: `.claude/skills/kxue43-pr-review/SKILL.md`

### Front matter — `allowed-tools`

- Added `Agent`.
- Removed `mcp__jarvis-registry__discover_agents`, `mcp__jarvis-registry__execute_agent`,
  `mcp__jarvis-registry__execute_prompt`, `mcp__jarvis-registry__read_resource`.
- Kept `mcp__jarvis-registry__discover_servers` and `mcp__jarvis-registry__execute_tool` for
  web search (unfamiliar technology).

### `start` — Step 2

Replaced inline GitHub fetching with:

> Invoke the `kxue43-fetch-pr-data` subagent, passing `$pr_url` as the prompt. If the result
> starts with `ERROR:`, stop and report verbatim. Otherwise parse `PR_TITLE`, `BASE_BRANCH`,
> `LABELS`, and `DESCRIPTION`.

### `followup` — Step 4, pre-review preparation

Replaced old steps 1–2 with a single step that:
- Strips brackets from `changes_requested` labels and joins with spaces
  (e.g. `[C1, M2]` → `C1 M2`).
- Invokes `kxue43-fetch-pr-comments` with `$pr_url` + label list as the prompt.
- Stops on `ERROR:`.
- Parses `LABEL_MAP` and `## Thread:` sections from the result.

Old steps 3–5 retained verbatim as new steps 2–4, with the cross-reference updated
("per point 3" → "per point 2").

---

## Files created / modified

| File | Change |
|---|---|
| `.claude/agents/kxue43-fetch-pr-data.md` | Created |
| `.claude/agents/kxue43-fetch-pr-comments.md` | Created |
| `.claude/skills/kxue43-pr-review/SKILL.md` | Updated |
| `set-up.sh` | Added `~/.claude/agents → .claude/agents/` symlink (done separately) |

---

## Verification

1. Run `/kxue43-pr-review start` on a real PR. Confirm no `discover_servers` GitHub output in
   the main context; report populated with title, base branch, labels, summary.
2. Run `/kxue43-pr-review followup` with known `changes_requested` labels. Confirm:
   - `LABEL_MAP` is correct (FOUND/NOT_FOUND per label).
   - Threads with bot-preceded signal comments include the full thread.
   - Multiple threads for the same label are all surfaced.
   - Main skill ratings (addressed/partial/unaddressed) match thread content.
