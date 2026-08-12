# Converting Two Subagents to the CLI+wrapper-skill Pattern

@.claude/agents/kxue43-fetch-pr-data.md—This subagent has been working fairly well until about two days ago,
when it suddenly says that the `pull_request_read` MCP tool it uses no longer returns the PR message body.
Anyway, I think it's time to use a different architecture for both this `kxue43-fetch-pr-data` and the `kxue43-fetch-pr-comment` subagents,
before what they do is pretty "old school" software tasks and do not have to be handled by an LLM.
A "dedicated CLI plus Claude Code skill wrapper of the CLI" might be a better pattern.

**My idea of this change is:** Turn both the `kxue43-fetch-pr-data` and the `kxue43-fetch-pr-comment` subagents to "CLI+skill-wrapper" combination.
To be more detailed:
- @.claude/CLAUDE.md#L8—This is the global CLAUDE.md file that my `~/.claude/CLAUDE.md` symlinks to.
  Here, soften the "never use `gh` CLI" to something like "only allowed to use by skills; never invokle by itself".
- Convert what @.claude/agents/kxue43-fetch-pr-data.md does to a new shell script at `bin/fetch-pr-data`.
  The shell script pulls the same type of information that the subagent `kxue43-fetch-pr-data` is designed to pull, **but via the `gh` CLI**.
  It prints the same-formatted error message for successful result to `stdout`
  (is this the standard way for a CLI to pass contents to an LLM when invoked via Claude Code skill?).
  Note that: (1) don't worry about auth, the human user always handles auth first; if not auth'ed, simply return the error message;
  (2) the response JSON schema used by the `gh` CLI and used by the GitHub official MCP (via the `jarvis-registry` MCP gateway) are diffderent,
  you (Claude Code) need to make some `gh` calls or look up documentation by web search to pin down the response schema of `gh`;
  if you need a real PR example, you can use https://github.com/ascending-llc/jarvis-registry/pull/511.
  The shell script accepts one positional argument which is the GitHub PR's URL.
- The `.claude/skills/` folder in this project is the symlink target of my user-scope skill folder `~/.claude/skills/`,
  so anything in this folder become my user-scoped Claude Code skill. With the `bin/fetch-pr-data` script,
  add a corresponding "wrapper skill" `.claude/skills/kxue43-fetch-pr-data` for it,
  set `user-invocable: false` meaning this skill is only intended to be invoked by LLM, not human user directly.
  The skill simply delegates the `fetching` of PR to the `bin/fetch-pr-data` shell script.
  The skill accepts one positional argument which is the GitHub PR's URL, and relay it to the shell script.
- Then do the same thing for the @.claude/agents/kxue43-fetch-pr-comments.md subagent—replacing it with a `bin/fetch-pr-comments` shell script that
  uses `gh` and `.claude/skills/kxue43-fetch-pr-comments` wrapper skill. Same `user-invocable: false`,
  same GitHub PR URL as the only positional argument. Preserver the same kind of error and successful output.
  **Similar to the subagent, only fetches inline review threads and Issue/PR-level comments ( I don't use the third type of "review comments" at all).**
  Pin down the response schema of `gh` first. If you need an example,
  https://github.com/ascending-llc/jarvis-registry/pull/510 has both types of comments I actually use.
  Note that this shell script requires looping and possibly handling pagination,
  and the successful result format is a bit more complex. Handle these carefully.
