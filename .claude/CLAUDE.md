# Global Preferences

## Code and technical research: tool priority

In coding, code review, code research, or technical research sessions:
- Use `Read`, `Grep`, and `Bash` to read local files and understand the codebase.
- Use the `git` CLI to gather Git and repository information.
- For GitHub information that cannot be obtained via the `git` CLI, discover "github" related tools from the `jarvis-registry` MCP server and use them. Never use the `gh` CLI — it sometimes returns incomplete data.

## Web search: tool priority

For any web search or URL fetch, always discover "tavily" related tools from `jarvis-registry` and use them.
Never use the built-in `WebSearch` or `WebFetch` tools.

## Authentication

If any tool requires authentication and it cannot be completed automatically, stop immediately and prompt the user to authenticate before proceeding.

## Argument and input validation

Check all required inputs at the start of a task. If any are missing, report exactly which ones are absent and stop before taking any action.

## Unfamiliar technology

When uncertain about a library, API, or technology, perform web search to verify behavior before drawing conclusions. Do not guess.

## GitHub side effects

Do not post comments, create issues, or take any action visible on GitHub unless the user explicitly asks for it. All output defaults to local files.

## Spec Writing Standards

When writing a spec or note file during a research session:
- For every file or doc fetched that produced a finding relevant to the goal, extract only the relevant signature, snippet, or punchline — not a summary of the file
- Do not include files that produced no distinct finding
- Every line must be load-bearing — do not include content for the sake of completeness
