---
name: kxue43-session-file
description: "Create or load a session manifest file for structured research workflows. Subcommands: `new <path>` scaffolds a boilerplate session file; `load <path>` reads it and all listed spec files to prime context before beginning work."
disable-model-invocation: true
argument-hint: "new <rel-path> | load <rel-path>"
arguments: [subcommand, path]
allowed-tools: Read Write Bash
---

## Arguments

| Variable | Description |
|----------|-------------|
| `$subcommand` | Either `new` or `load` |
| `$path` | Path relative to CWD of the session manifest file |

**Both arguments are required.** If either is missing, stop and tell the user which is absent before doing anything else.

---

## Subcommand: `new`

When `$subcommand` is `new`:

1. **Never overwrite an existing session file.** Check whether a file already exists at `$path`
   (e.g. via `Bash test -e "$path"`). If it does, stop immediately and tell the user a session
   file already exists at that path — do not proceed.
2. Run `mkdir -p` on the parent directory of `$path`.
3. Write the following content to `$path` exactly:

```
---
load:
  - specs/PLACEHOLDER.md
goal: "TODO: describe what you want to research or accomplish this session"
---

## Session Notes

<!--
  `load:` paths are relative to CWD, not to this file.
  Record prior session conclusions, open questions, and constraints here.
  This file is committed to git — write it as a future-you artifact.
-->
```

4. Print: `Created: $path`. Do nothing else. Do not start a session.

---

## Subcommand: `load`

When `$subcommand` is `load`:

1. Read the session file at `$path`. If no file exists at that path, stop immediately and tell the user it was not found.
2. Parse its YAML front matter. Extract:
   - `load:` — list of file paths relative to CWD
   - `goal:` — the session objective string
3. Internalize the extracted `goal:`: this is your north star for deciding what is relevant
   in the files you are about to read.
4. With the goal in mind, read every file listed under `load:`, in order.
   - If any file is missing, stop immediately and report which path was not found.
     Do not proceed with partial context.
5. Read the markdown body of the session file (everything below the front matter) to absorb
   any prior session notes, open questions, and constraints recorded there.
6. Output a confirmation block in this format:

---
**Session loaded**

| File | Summary |
|------|---------|
| `specs/A1.md` | one-sentence summary inferred from content |
| `specs/B2.md` | one-sentence summary inferred from content |

**Goal:** (verbatim from front matter)

All context loaded. Awaiting your first message.

---

7. Stop. Do not begin any work, ask clarifying questions, or offer suggestions
   until the user sends their first message.
