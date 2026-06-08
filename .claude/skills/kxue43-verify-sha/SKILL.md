---
name: kxue43-verify-sha
description: "Verify that local HEAD SHA matches the remote branch SHA using git only."
context: fork
user-invocable: false
allowed-tools: Bash
model: haiku
---

## SHA Verification

Run the following three commands in order:

1. `git rev-parse --abbrev-ref HEAD` — get the local branch name.
2. `git ls-remote origin refs/heads/<local_branch>` — get the remote SHA (the first whitespace-delimited field of the output).
3. `git rev-parse HEAD` — get the local HEAD SHA.

Then compare:

- If the `git ls-remote` output is empty (the remote ref does not exist), output:
  ```
  VERIFY-SHA: FAIL — no remote ref found for branch <branch-name>
  ```
- If the remote SHA and local HEAD SHA differ, output:
  ```
  VERIFY-SHA: FAIL — local <local-sha> ≠ remote <remote-sha>
  ```
- If both SHAs match, output:
  ```
  VERIFY-SHA: PASS
  ```

Output exactly one line in one of the three formats above. No other output.
