---
name: kxue43-write-specs
description: "Write one or more technical spec files as Markdown, at caller-specified paths, using context already established in this session (typically invoked at the end of a design/planning conversation). Takes a path-to-topic mapping plus a shared prompt of overall instructions."
disable-model-invocation: true
argument-hint: "[path_mapping] [prompt]"
arguments: [path_mapping, prompt]
allowed-tools: Bash Read Write Edit Grep mcp__jarvis-registry__discover_servers mcp__jarvis-registry__execute_tool
---

## Arguments

| Variable | Description |
|----------|-------------|
| `$path_mapping` | One or more items separated by `;;`. Each item is `local_file_path :: topic` — the output path for that spec, and a short label for what it covers. The last item does not need a trailing `;;`. |
| `$prompt` | Plain-language "overall instructions" that apply to every spec being written — e.g. a technical decision just finalized, shared constraints, or context that cuts across all paths. |

**Both arguments are required.** If either is missing, stop and tell the user which is absent before doing anything else.

### How to read `topic`

This skill is invoked at the end of a back-and-forth design/planning conversation, after decisions are finalized and gaps are filled — not cold. Each `topic` is a short pointer back into *this session's own established context*, not a self-contained spec of what to write. Before writing any spec, resolve each `topic` against the conversation that led up to this invocation: what was decided, what problem was being solved, what the agreed-upon approach was. Combine that with `$prompt`'s shared instructions. Do not treat `topic` as the entirety of what the spec should say.

**Never overwrite an existing spec.** Before any research or exploration begins, parse `$path_mapping` into `(local_file_path, topic)` pairs and check every `local_file_path` (e.g. via `Bash test -e`, or `Read`). If any already exists, stop immediately and tell the user which path(s) already have a spec — do not write any file, even the ones that don't yet exist.

---

## Hard constraints — apply for the entire duration of this skill, not just at the start

- Do every step yourself, directly, in this conversation. **Never use the Task/Agent tool** for any part of this workflow — esp. for parallelizing independent pairs via subagents, since they don't inherit this session's context.
- **Never call the Skill tool** for any skill while running this workflow. Everything needed is inlined below.
- Process pairs **strictly one at a time, in the order given**. Fully finish and confirm one spec file before starting research on the next.

---

## Process (repeat for each pair, in order)

### 1. Understand the topic

Resolve this pair's `topic` against the conversation that led up to this invocation, and combine that with `$prompt`. Identify:
- The area of the codebase it concerns (frontend, backend service, route, MCP tool, model, etc.).
- Whether it is a bug fix, refactor, new feature, or cleanup.
- Any specific files, functions, or patterns already discussed, and any decisions already finalized.

### 2. Explore the codebase

Use `Read`, `Grep`, and `Bash` to gather the concrete details needed to write a precise spec:
- Find the relevant files and read the specific sections that need to change.
- Note exact file paths and line numbers for every problem and every proposed change.
- Understand the surrounding architecture: what calls what, what the established patterns are, what must not break.
- When useful, check git history (`git log`, `git blame`, `git show`) for why the current code looks the way it does or for related prior changes.
- Identify all files that will need to change, including tests.

Do not write the spec file until you have enough concrete detail that every statement in it can reference a specific file or line. Vague descriptions ("improve the code") are not acceptable.

### 3. Write the spec file

Write the Markdown file to this pair's `local_file_path` using the format below. Create parent directories if needed.

### 4. Confirm and move on

Print `Spec written: <local_file_path>`, then continue to the next pair — no subagents, no Skill tool, do it yourself. Save the recap for the final summary at the end; don't repeat it here.

---

## Output Format

`<Ticket ID>` in the title below is the issue/ticket identifier this spec is for (e.g.
`AS-1234`), typically derived from this pair's `local_file_path` basename (`as-1234.md` → `AS-1234`) or
from `topic`/`$prompt` if either names one. If no ticket applies, drop the ticket segment and the
em-dash, leaving just the imperative title.

```markdown
# <Ticket ID> — <Concise Imperative Title>

## Background

<2–4 sentences. What is the current state, why is it a problem, and why is this spec file
being created now. Reference specific files by path where relevant.>

---

## Changes

### 1. <Title of first change>

<Concrete description. What exactly changes, where (file + line if applicable), and why.
Each change section should be self-contained enough that a developer can act on it without
reading external documents.>

### 2. <Title of second change>

...

---

## What does NOT change

<Bullet list of behaviour, interfaces, or files that are explicitly out of scope.
Omit this section if the spec is narrow enough that scope creep is not a risk.>

---

## Acceptance Criteria

- [ ] <Specific, testable condition.>
- [ ] <...>

---

## Files to Change

| File | Change |
|---|---|
| `path/to/file.py` | One-line description of the change |

---

## Risk

<One sentence. Where is the realistic risk of regression or breakage, and what is the
mitigation (e.g. which existing tests act as the guard).
Omit this section for trivial or fully-isolated changes.>
```

---

## Quality Rules

- Every problem described must cite a file path. Line numbers wherever they add clarity. For concerns about absence (missing handling, missing tests), cite the production code where the gap is observable rather than the non-existent file.
- Every proposed change must explain both *what* and *why*.
- Acceptance criteria must be independently verifiable — no "code is clean" or "looks good".
- The Files to Change table must be complete: if a file will need touching (including tests), it must appear in the table.
- Do not propose changes beyond what this pair's `topic` (as resolved against session context) and the shared `$prompt` ask for. If you notice adjacent issues, mention them briefly at the end of the spec file as "Out of scope / follow-up" rather than expanding the spec.

---

## When all pairs are done

Print a final summary: for each spec written, its path and a one- or two-sentence recap of the core problem and key changes. Before finishing, confirm to yourself: did you avoid the Task/Agent tool and the Skill tool for this entire workflow? If not, say so explicitly rather than staying silent about it.
