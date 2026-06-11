# 009 — GitNexus analysis subagent for kxue43-pr-review

## Problem

`kxue43-pr-review` explored local context via `git log`, `git blame`, `Read`, `Grep` — file-centric
tools that show *what* changed but cannot trace *what depends on it* across the 750-file
jarvis-registry codebase. Blast-radius analysis and API route consumer mapping required manual
grep-and-trace, which is slow and misses second-order impacts.

jarvis-registry's GitNexus MCP server (already on `jarvis-registry`) indexes the repo into a
35k-edge knowledge graph and exposes structured impact tools via MCP. The repo is fully indexed.

## What changed

### New file: `.claude/agents/kxue43-gitnexus-analysis.md`

Internal subagent (model: sonnet) spawned by `kxue43-pr-review` only.

**Input:** a git base ref string, e.g. `origin/main`

**Steps:**
1. `git remote -v` guard — hard stop if remote doesn't contain `ascending-llc/jarvis-registry`
2. Discover GitNexus via `jarvis-registry` MCP — hard stop with distinct error on auth failure
3. `detect_changes` (scope: compare, base_ref from prompt) → changed symbols, affected processes, risk level
4. `impact` (upstream, d=1+d=2) for up to 5 HIGH-risk symbols
5. `api_impact` for any changed file under `/api/` or `/routes/`
6. `tool_map` for any changed MCP tool handler files
7. Output digest beginning with `## GitNexus Analysis`, ≤10k tokens; drops LOW-risk items, d=3 results, routes with no mismatches and <4 consumers

**Error sentinel:** `ERROR: …` (hard stop; skill checks `if result starts with ERROR:`)
**Success sentinel:** `## GitNexus Analysis` (cannot be confused with error)

### Updated: `kxue43-pr-review/SKILL.md`

- **`start`**: new step 5 invokes `kxue43-gitnexus-analysis` after diff collection; existing steps 5–7 renumbered 6–8
- **`followup`**: GitNexus invocation block added after "Obtain the PR diff", before the three review tracks

Both invocations: pass `origin/<base_branch>`, hard-stop on `ERROR:` response, use digest to guide review depth.

### Updated: `.claude/agents/kxue43-fetch-pr-data.md`

Added explicit `ERROR: please authenticate with jarvis-registry` hard stop to the `execute_tool` call (step 3) — previously only the `discover_servers` step had this check.

### Updated: `.claude/agents/kxue43-fetch-pr-comments.md`

Replaced generic `On failure of either fetch, output ERROR: <reason>` with explicit auth-failure message for authentication errors; non-auth failures still use `ERROR: <reason>`.

## Tool selection rationale

| Tool | Used | Reason |
|---|---|---|
| `detect_changes` | yes | maps diff hunks → symbols + processes + risk; core of the analysis |
| `impact` | yes | blast radius (d=1/d=2) for HIGH-risk symbols; catches missed callers |
| `api_impact` | yes | route consumer count + shape mismatches; relevant given jarvis-registry REST API surface |
| `tool_map` | yes | MCP tool handler metadata; directly relevant as jarvis-registry is an MCP gateway |
| `query` / `context` | no | too open-ended for structured review; subagent would need to author queries |
| `shape_check` | no | JS `.json({})` extraction pattern; Python/FastAPI shape detection unverified |
| `route_map` | no | covered by `api_impact` which combines route + impact data |
| `cypher` | no | requires authoring Cypher inline; too raw for a skill subagent |

## Context window impact

Raw GitNexus output for a large PR: ~30–50k tokens if inlined. Subagent isolates this; digest
returned to main agent: ≤10k tokens. Net saving over inlining: 20–40k tokens per session.
