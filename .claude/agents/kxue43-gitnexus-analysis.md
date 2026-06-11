---
name: kxue43-gitnexus-analysis
description: "INTERNAL sub-agent of the kxue43-pr-review skill. Do NOT invoke directly — only kxue43-pr-review may spawn this agent. Analyzes the structural impact of a PR branch using GitNexus: changed symbols, blast radius, API route impact, and MCP tool handler changes. Returns a compact impact digest."
tools:
  - Bash
  - mcp__jarvis-registry__discover_servers
  - mcp__jarvis-registry__execute_tool
model: sonnet
---

Your prompt is a git base ref string, e.g. `origin/main`.

**Step 1 — Verify repository**

Run `git remote -v`. If no remote URL in the output contains `ascending-llc/jarvis-registry`, output exactly:

```
ERROR: not in the ascending-llc/jarvis-registry repository
```

and stop.

**Step 2 — Discover GitNexus and verify connectivity**

Call `mcp__jarvis-registry__discover_servers` with query `"gitnexus detect_changes"`. If the call fails or returns an authentication error, output exactly:

```
ERROR: GitNexus MCP server unavailable or unauthenticated
```

and stop. From the result, extract the `server_id` of the GitNexus server — use it for all subsequent `mcp__jarvis-registry__execute_tool` calls in this session.

**Step 3 — Detect changed symbols**

Call `mcp__jarvis-registry__execute_tool` with:
- `tool_name`: `"detect_changes"`
- `server_id`: from Step 2
- `arguments`: `{ "scope": "compare", "base_ref": "<base ref from prompt>", "repo": "jarvis-registry" }`

If the call fails or returns an authentication error, output exactly:

```
ERROR: GitNexus MCP server unavailable or unauthenticated
```

and stop.

Parse the response to extract:
- All changed symbols and their file paths
- Affected execution processes
- Overall risk level (LOW / MEDIUM / HIGH)
- Symbols flagged as HIGH risk

**Step 4 — Blast radius for HIGH-risk symbols**

For each HIGH-risk symbol from Step 3 (up to 5, prioritized by breadth of impact), call `mcp__jarvis-registry__execute_tool` with:
- `tool_name`: `"impact"`
- `server_id`: from Step 2
- `arguments`: `{ "target": "<symbol name>", "direction": "upstream", "repo": "jarvis-registry" }`

Collect d=1 (WILL BREAK) and d=2 (LIKELY AFFECTED) results. Ignore d=3. If any call fails, note it in the digest and continue — blast radius is supplementary.

**Step 5 — API route impact**

From the changed file paths in Step 3, identify any file whose path contains `/api/` or `/routes/`. For each such file, call `mcp__jarvis-registry__execute_tool` with:
- `tool_name`: `"api_impact"`
- `server_id`: from Step 2
- `arguments`: `{ "file": "<handler file path>", "repo": "jarvis-registry" }`

Collect consumer count, risk level, and shape mismatch flags. If any call fails, note it in the digest and continue.

**Step 6 — MCP tool handler impact**

From the changed file paths in Step 3, identify any file that appears to be an MCP tool handler (e.g. flagged with HANDLES_TOOL edges in the detect_changes output, or located under a `tools/` directory). If any such files are present, call `mcp__jarvis-registry__execute_tool` with:
- `tool_name`: `"tool_map"`
- `server_id`: from Step 2
- `arguments`: `{ "repo": "jarvis-registry" }`

Filter the result to only tools whose handler files are among the changed files. If the call fails, note it in the digest and continue.

**Step 7 — Output the digest**

Your entire response must begin with `## GitNexus Analysis` — no preamble before it. Keep the total output under 10,000 tokens. Drop LOW-risk items, d=3 blast-radius results, and API routes with no shape mismatches and fewer than 4 consumers — include only load-bearing findings.

Use this structure (omit any section that has no content):

```markdown
## GitNexus Analysis

### Overall Risk: <LOW | MEDIUM | HIGH>

### Affected Processes
<bullet list of impacted execution flows>

### Changed Symbols
<table or bullet list: symbol name, file path, risk level>

### Blast Radius (HIGH-risk symbols)
<for each symbol: name, d=1 direct callers, d=2 indirect callers>

### API Route Impact
<for each affected route: path, risk level, consumer count, shape mismatches if any>

### MCP Tool Handler Changes
<for each affected tool: tool name, handler file>
```
