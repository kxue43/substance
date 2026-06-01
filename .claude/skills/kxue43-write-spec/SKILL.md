---
name: kxue43-write-spec
description: "Write a technical spec file as a Markdown. Two required arguments: path to write the output file, and a prompt string describing what the spec file should cover."
disable-model-invocation: true
argument-hint: "[output_file] [prompt]"
arguments: [output_file, prompt]
allowed-tools: Bash Read Write Edit Grep mcp__jarvis-registry__discover_agents mcp__jarvis-registry__discover_servers mcp__jarvis-registry__execute_agent mcp__jarvis-registry__execute_prompt mcp__jarvis-registry__execute_tool mcp__jarvis-registry__read_resource
---

## Arguments

| Variable | Description |
|----------|-------------|
| `$output_file` | Path relative to CWD where the Markdown spec file will be written |
| `$prompt` | Plain-language description of what the spec file should cover |

**Both arguments are required.** If either is missing, stop and tell the user which is absent before doing anything else.

---

## Allowed Tools

You may freely use all Claude Code built-in tools: `Bash`, `Read`, `Write`, `Edit`, `Grep`.

You may also use:
- The **`jarvis-registry`** MCP server (`mcp__jarvis-registry__*`) — for GitHub-related
  operations (reading PR descriptions, issue details, comments, and diffs) when the prompt
  references a GitHub PR or issue, and for web search when you need to verify behaviour of
  an unfamiliar library, API, or technology. Discover the relevant tools with
  `mcp__jarvis-registry__discover_servers` and call them via `mcp__jarvis-registry__execute_tool`.
  Prefer local `git` CLI for anything retrievable that way.

---

## Process

### 1. Understand the prompt

Read `$prompt` carefully. Identify:
- The area of the codebase it concerns (frontend, backend service, route, MCP tool, model, etc.).
- Whether it is a bug fix, refactor, new feature, or cleanup.
- Any specific files, functions, or patterns mentioned.

### 2. Explore the codebase

Use `Read`, `Grep`, and `Bash` to gather the concrete details needed to write a precise spec:
- Find the relevant files and read the specific sections that need to change.
- Note exact file paths and line numbers for every problem and every proposed change.
- Understand the surrounding architecture: what calls what, what the established patterns are, what must not break.
- Identify all files that will need to change, including tests.

Do not write the spec file until you have enough concrete detail that every statement in it can reference a specific file or line. Vague descriptions ("improve the code") are not acceptable.

### 3. Write the spec file

Write the Markdown file to `$output_file` using the format below. Create parent directories if needed.

---

## Output Format

```markdown
# <Title> — <concise imperative title>

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
- Do not propose changes beyond what `PROMPT` asks for. If you notice adjacent issues, mention them briefly at the end as "Out of scope / follow-up" rather than expanding the spec.
- Write in the same voice as the rest of the spec files in this project.
