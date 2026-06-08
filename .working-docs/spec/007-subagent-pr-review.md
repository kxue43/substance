# Bug & Concern Report — PR #2 (`kxue43/dotfiles`)

## BUG-1 — Wrong discovery query in `kxue43-fetch-pr-comments` *(confirmed)*

**File:** `.claude/agents/kxue43-fetch-pr-comments.md`

**Step 2** instructs the subagent:

> *"Call `mcp__jarvis-registry__discover_servers` with query `"github pull request comments"`. This surfaces `pull_request_read`."*

The inline assertion is **factually wrong**. Running that exact query against the registry returns:

| Rank | Tool returned | Relevance |
|---|---|---|
| 1 | `add_issue_comment` | 0.999 |
| 2 | `update_pull_request` | 0.995 |
| 3 | `request_copilot_review` | 0.994 |
| 4 | `list_pull_requests` | 0.994 |
| 5 | `search_pull_requests` | 0.993 |

`pull_request_read` does not appear at all. The "pick the highest-relevance result" heuristic will therefore select `add_issue_comment` — a **write** tool — and the fetch will fail or produce garbage.

**Fix:** Change the query string to `"github pull request read"`, which returns `pull_request_read` at score **1.0** (confirmed — same query used correctly by the sibling subagent `kxue43-fetch-pr-data`).

```diff
-Call `mcp__jarvis-registry__discover_servers` with query `"github pull request comments"`.
-This surfaces `pull_request_read`.
+Call `mcp__jarvis-registry__discover_servers` with query `"github pull request read"`.
+This surfaces `pull_request_read` at the top of the results.
```

---

## CONCERN-1 — `after` cursor parameter is undocumented in the formal schema *(unresolved)*

**File:** `.claude/agents/kxue43-fetch-pr-comments.md`, Step 2

The subagent's pagination instruction for `get_review_comments` is:

> *"Paginate while `pageInfo.hasNextPage` is true: pass `after: <pageInfo.endCursor>` on the next call."*

The **response** side is confirmed correct — live data from PR #364 shows `pageInfo.hasNextPage` and `pageInfo.endCursor` exactly as expected. However, the formal tool schema registered for `pull_request_read` lists only `page` and `perPage` as parameters; `after` does not appear in it. The method description text does say *"Use cursor-based pagination (perPage, after)"*, which suggests the parameter is intentionally supported, but it has never been exercised (PR #364 returned all 13 threads in a single page).

**Risk:** If the tool silently ignores an unrecognised `after` key and always returns from the first page, PRs with more than 100 review threads will be silently truncated. Low probability in practice but worth a one-time smoke test on a large PR before relying on the followup workflow at scale.
