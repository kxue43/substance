# Inline PR-review scripts into their owning skill folders

## Background

`bin/fetch-pr-comments`, `bin/fetch-pr-data`, and `bin/fetch-single-comment` are only ever
invoked from one place each: `fetch-pr-comments` and `fetch-pr-data` from
`.claude/skills/kxue43-pr-review/SKILL.md` (lines 69–73 and 269–273), and `fetch-single-comment`
from `.claude/skills/kxue43-fetch-single-comment/SKILL.md` (lines 17–21). They are on `PATH`
today only because `set-up.sh` symlinks everything under `bin/` into `~/.local/bin`, and each has
a matching `completions/<name>` file for interactive tab-completion.

The goal is to publish `kxue43-pr-review` and `kxue43-fetch-single-comment` to a team "skills
hub" so other users can drop the skill folder into their own `~/.claude/skills/`. A script that
depends on being on `PATH`, or that sources `lib/utils.sh` via a path relative to the
`substance` repo, is not portable to that use case. Per Claude Code's official skills docs
(`code.claude.com/docs/en/skills`), the supported pattern for this is a `scripts/` subdirectory
inside the skill folder, referenced via the `${CLAUDE_SKILL_DIR}` substitution — which resolves
to "the directory containing the skill's `SKILL.md` file... regardless of the current working
directory" and is substituted both in the skill body and in `allowed-tools` Bash rules.

`bin/fetch-pr-comments` additionally hardcodes the reviewer's GitHub login as the literal string
`"kxue43"` in its `jq` program (`bin/fetch-pr-comments:37,39,51`) and in `SKILL.md` prose
(`.claude/skills/kxue43-pr-review/SKILL.md:286`, "the reviewer (kxue43)"). This must become
self-service (resolved via `gh` at runtime) for the skill to work for any other team member.

Neither `bin/fetch-pr-data` nor `bin/fetch-single-comment` reference any GitHub login (confirmed
by inspection — no `kxue43` string in either file), so per the scope agreed for this change, they
get no `gh`/login-resolution logic, only the relocation and output-contract changes below.

None of the three scripts currently call any `kxue43::*` helper from `lib/utils.sh` despite
sourcing it (`bin/fetch-pr-comments:5`, `bin/fetch-pr-data:5`, `bin/fetch-single-comment:5`) — the
`source` line exists only because of the repo's standard `bin/` script template. It can be
dropped with no behavior change, which is required anyway for portability.

---

## Changes

### 1. Relocate the three scripts into their owning skill's `scripts/` directory

Move (not copy):
- `bin/fetch-pr-comments` → `.claude/skills/kxue43-pr-review/scripts/fetch-pr-comments`
- `bin/fetch-pr-data` → `.claude/skills/kxue43-pr-review/scripts/fetch-pr-data`
- `bin/fetch-single-comment` → `.claude/skills/kxue43-fetch-single-comment/scripts/fetch-single-comment`

`kxue43-fetch-single-comment`'s script is **not** duplicated into `kxue43-pr-review`'s folder:
`kxue43-pr-review/SKILL.md` already delegates to the `kxue43-fetch-single-comment` skill via the
`Skill` tool rather than calling the binary directly (lines 57, 238), and `${CLAUDE_SKILL_DIR}`
resolves per the currently-loading skill, so it correctly points at
`kxue43-fetch-single-comment/scripts/` when that skill runs.

Preserve the executable bit (`chmod +x`) on both relocated files.

`set-up.sh` needs no code changes: it symlinks `.claude/skills/<name>` as whole folders (so
`scripts/` rides along automatically) and populates `~/.local/bin` from a dynamic `ls -1 bin/`
listing with a stale-symlink cleanup pass — removing the three files from `bin/` is enough for
them to stop appearing in `~/.local/bin` on the next run.

### 2. Drop the `lib/utils.sh` dependency from all three scripts

Remove this line from all three (currently line 5 in each):

```bash
source "$(cd "$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")" && pwd)/../lib/utils.sh"
```

No replacement is needed — none of the three scripts call `kxue43::log_error`,
`kxue43::log_info`, or `kxue43::get_env_prefix`. This makes each script fully self-contained
(only depends on `gh`, `jq`, and bash builtins), which is required for the skill folder to be
portable outside this repo.

### 3. `fetch-pr-comments`: resolve the GitHub login via `gh`, remove the hardcoded `"kxue43"`

Add a `gh`-existence check and a `_resolve_login` helper, called before any GitHub API call.
Full new content for `.claude/skills/kxue43-pr-review/scripts/fetch-pr-comments`:

```bash
#!/usr/bin/env bash

set -eu -o pipefail

_pr_url_regex='^https://github\.com/([^/]+)/([^/]+)/pull/([0-9]+)/?$'

# Groups inline review comments into threads (root = comment with no
# in_reply_to_id; GitHub disallows replies-to-replies, so in_reply_to_id
# always points at the thread root), keeps only threads/comments with the
# current gh user's "This is change request [Xn]." signal in the first
# paragraph, and orders the result by severity tier (C, M, m) then number.
# shellcheck disable=SC2016
_jq_program='
def norm: gsub("\r"; "");
def first_para: (.body | norm | split("\n\n") | .[0]);
def label_of:
  first_para as $p
  | if ($p | test("^This is change request \\[[A-Za-z0-9]+\\]\\.$"))
    then ($p | capture("^This is change request \\[(?<l>[A-Za-z0-9]+)\\]\\.$") | .l)
    else null
    end;
def tier_rank:
  if (.[0:1] == "C") then 0
  elif (.[0:1] == "M") then 1
  elif (.[0:1] == "m") then 2
  else 3
  end;
def num_part: (.[1:] | tonumber? // 0);

(
  $inline
  | map(. + {author: .user.login, thread_root: (.in_reply_to_id // .id)})
  | group_by(.thread_root)
  | map(sort_by(.created_at))
  | map(select(any(.[]; .author == $login)))
  | map(
      (first((.[] | select(.author == $login) | label_of) | select(. != null))) as $label
      | select($label != null)
      | {
          label: $label,
          created_at: .[0].created_at,
          kind: "thread",
          entries: map({author, path, line: (.line // .original_line // null), body: (.body|norm)})
        }
    )
) as $thread_groups
| (
    $issue
    | map(select(.user.login == $login))
    | map(label_of as $l | select($l != null) | {label: $l, created_at, kind: "comment", body: (.body|norm)})
  ) as $comment_groups
| ($thread_groups + $comment_groups) as $all
| (
    $all
    | group_by(.label)
    | map({label: .[0].label, items: sort_by(.created_at)})
    | sort_by([(.label|tier_rank), (.label|num_part)])
    | map(.items)
    | (add // [])
  ) as $ordered_items
| ([$ordered_items[].label] | unique) as $found_labels
| {
    items: $ordered_items,
    label_map: ($ARGS.positional | map({label: ., found: (. as $r | ($found_labels | index($r)) != null)}))
  }
'

_render_blockquote() {
  sed -e 's/^/> /' -e 's/^> $/>/'
}

_gh_api_paginated() {
  local endpoint=$1 stderr_file=$2
  local raw

  if ! raw=$(gh api "$endpoint" --paginate --slurp 2>"$stderr_file"); then
    return 1
  fi

  jq 'flatten(1)' <<<"$raw"
}

_resolve_login() {
  if ! command -v gh &>/dev/null; then
    echo "ERROR: gh CLI not found. Install it: https://cli.github.com/"
    return 1
  fi

  local raw
  if ! raw=$(gh auth status --json hosts --jq '.hosts."github.com"[0].login' 2>&1); then
    if [[ $raw == *"unknown flag"* ]]; then
      echo "ERROR: gh CLI is too old (needs >= 2.81.0 for 'gh auth status --json'). Upgrade gh and try again."
    else
      echo "ERROR: $raw"
    fi
    return 1
  fi

  local login
  login=$(head -n1 <<<"$raw")

  if [[ -z $login ]] || [[ $login == "null" ]] || ! [[ $login =~ ^[A-Za-z0-9-]+$ ]]; then
    echo "ERROR: not logged into GitHub via gh. Run: gh auth login"
    return 1
  fi

  printf '%s' "$login"
}

main() {
  if (($# > 0)) && [[ $1 == "-h" ]]; then
    cat <<'EOF'
Usage: fetch-pr-comments [-h] PR_URL LABEL [LABEL...]

Fetch reviewer comments — authored by the current `gh`-authenticated GitHub
user — on a GitHub PR via the `gh` CLI: inline review threads and issue/PR-
level comments (review-level "reviews" are not fetched). Only threads/
comments whose comment opens with the exact first paragraph `This is change
request [Xn].` are kept. On success, writes a fixed plain-text format to a
temporary file and prints that file's absolute path to stdout. Requires the
`gh` CLI (>= 2.81.0) to be installed and authenticated; on any failure
(missing gh, unsupported gh version, not logged in, or a GitHub API error)
prints `ERROR: <reason>` to stdout instead.

ARGUMENTS:
    PR_URL      Full URL to the GitHub pull request, e.g.
                https://github.com/owner/repo/pull/123
    LABEL       One or more finding labels without brackets (e.g. C1 M2) to
                check for a matching reviewer comment

OPTIONS:
    -h          Show this help message
EOF

    return 0
  fi

  if (($# < 1)); then
    echo "ERROR: fetch-pr-comments requires at least a PR_URL argument"

    return 0
  fi

  local pr_url=$1
  shift 1

  # Re-split every remaining arg on whitespace so labels work whether the
  # caller passed them as separate words (C1 M2) or one quoted string ("C1 M2").
  local -a labels=()
  local raw_arg
  for raw_arg in "$@"; do
    local -a split_labels
    read -r -a split_labels <<<"$raw_arg"
    labels+=("${split_labels[@]}")
  done

  if ((${#labels[@]} == 0)); then
    echo "ERROR: no finding labels provided"

    return 0
  fi

  if ! [[ $pr_url =~ $_pr_url_regex ]]; then
    echo "ERROR: not a GitHub PR URL: $pr_url"

    return 0
  fi

  local login
  if ! login=$(_resolve_login); then
    echo "$login"

    return 0
  fi

  local owner=${BASH_REMATCH[1]} repo=${BASH_REMATCH[2]} number=${BASH_REMATCH[3]}

  stderr_file=$(mktemp)
  trap 'rm -f "$stderr_file"' EXIT

  local inline_flat issue_flat
  if ! inline_flat=$(_gh_api_paginated "repos/$owner/$repo/pulls/$number/comments" "$stderr_file"); then
    echo "ERROR: $(<"$stderr_file")"

    return 0
  fi

  if ! issue_flat=$(_gh_api_paginated "repos/$owner/$repo/issues/$number/comments" "$stderr_file"); then
    echo "ERROR: $(<"$stderr_file")"

    return 0
  fi

  local result
  result=$(jq -n --argjson inline "$inline_flat" --argjson issue "$issue_flat" --arg login "$login" --args "$_jq_program" -- "${labels[@]}")

  local outfile
  outfile=$(mktemp)

  {
    echo "LABEL_MAP:"
    jq -r '.label_map[] | "  [" + .label + "] → " + (if .found then "FOUND" else "NOT_FOUND" end)' <<<"$result"
    echo
    echo "---"

    local item
    while IFS= read -r item; do
      local kind label
      kind=$(jq -r '.kind' <<<"$item")
      label=$(jq -r '.label' <<<"$item")

      echo
      echo "## Thread: [$label]"
      echo

      if [[ $kind == thread ]]; then
        local entry
        while IFS= read -r entry; do
          local author path line body
          author=$(jq -r '.author' <<<"$entry")
          path=$(jq -r '.path' <<<"$entry")
          line=$(jq -r '.line // "(file)"' <<<"$entry")
          body=$(jq -r '.body' <<<"$entry")

          echo "- AUTHOR: $author; PATH: $path; LINE: $line"
          echo
          _render_blockquote <<<"$body"
          echo
        done < <(jq -c '.entries[]' <<<"$item")
      else
        local created_at body
        created_at=$(jq -r '.created_at' <<<"$item")
        body=$(jq -r '.body' <<<"$item")

        echo "CREATED: $created_at"
        echo
        _render_blockquote <<<"$body"
        echo
      fi

      echo "---"
    done < <(jq -c '.items[]' <<<"$result")

    local -a unlinked
    mapfile -t unlinked < <(jq -r '.label_map[] | select(.found == false) | .label' <<<"$result")

    if ((${#unlinked[@]} > 0)); then
      echo
      echo "## Unlinked labels (no matching reviewer comment found):"

      local u
      for u in "${unlinked[@]}"; do
        echo "- [$u]"
      done
    fi
  } > "$outfile"

  echo "$outfile"
}

if [[ "${BASH_SOURCE[0]}" == "$0" ]]; then
  main "$@"
fi
```

Key points on `_resolve_login`:
- `gh auth status --json hosts --jq '.hosts."github.com"[0].login'` was only given `--json`/`--jq`
  support in gh **v2.81.0** (merged 2025-09-25). On an older `gh`, this fails with
  `unknown flag: --json` (non-zero exit) — detected explicitly and reported as a
  distinct "upgrade gh" error rather than being misread as "not logged in".
- When genuinely logged out, `gh auth status` exits **0** and prints
  `You are not logged into any GitHub hosts. To log in, run: gh auth login` (verified by the
  user). This is distinguished from a real login by validating the captured first line against
  `^[A-Za-z0-9-]+$` (GitHub login charset) rather than string-matching gh's message text, since a
  real login is one token with no spaces and the "not logged in" sentence is not.
- A literal `null` is also treated as not-logged-in explicitly (checked before the charset regex,
  which would otherwise accept it as a valid token). This covers the case where `gh` is
  authenticated to a GitHub host other than `github.com`: `.hosts."github.com"[0].login`
  evaluates to JSON `null` in jq (indexing a missing key, then a missing array element, both
  return `null` rather than erroring), and `--jq` prints that as the text `null`.
- All of `_resolve_login`'s failure paths `echo "ERROR: ..."` and `return 1`; the caller in
  `main` does `if ! login=$(_resolve_login); then echo "$login"; return 0; fi`, reusing the
  captured stdout as the error message — consistent with the script's existing
  `if ! foo=$(...); then echo "ERROR: ..."; fi` idiom elsewhere.

### 4. `fetch-pr-data`: relocate + switch output to temp-file-path (no login/gh changes)

Full new content for `.claude/skills/kxue43-pr-review/scripts/fetch-pr-data` (identical to
today's `bin/fetch-pr-data` minus the `lib/utils.sh` source line, with the final `printf`
redirected to a temp file):

```bash
#!/usr/bin/env bash

set -eu -o pipefail

_pr_url_regex='^https://github\.com/[^/]+/[^/]+/pull/[0-9]+/?$'

main() {
  if (($# > 0)) && [[ $1 == "-h" ]]; then
    cat <<'EOF'
Usage: fetch-pr-data [-h] PR_URL

Fetch a GitHub pull request's title, base branch, and description via the `gh`
CLI. On success, writes a fixed plain-text format to a temporary file and
prints that file's absolute path to stdout. Auth is assumed to already be set
up; on any failure (including auth) prints `ERROR: <reason>` to stdout
instead.

ARGUMENTS:
    PR_URL      Full URL to the GitHub pull request, e.g.
                https://github.com/owner/repo/pull/123

OPTIONS:
    -h          Show this help message
EOF

    return 0
  fi

  if (($# != 1)); then
    echo "ERROR: fetch-pr-data requires exactly one positional argument PR_URL"

    return 0
  fi

  local pr_url=$1

  if ! [[ $pr_url =~ $_pr_url_regex ]]; then
    echo "ERROR: not a GitHub PR URL: $pr_url"

    return 0
  fi

  stderr_file=$(mktemp)
  trap 'rm -f "$stderr_file"' EXIT

  local json
  if ! json=$(gh pr view "$pr_url" --json title,body,baseRefName 2>"$stderr_file"); then
    echo "ERROR: $(<"$stderr_file")"

    return 0
  fi

  local title base_branch body
  title=$(jq -r '.title' <<<"$json")
  base_branch=$(jq -r '.baseRefName' <<<"$json")
  body=$(jq -r '(.body // "") | gsub("\r"; "")' <<<"$json")

  local outfile
  outfile=$(mktemp)

  printf 'PR_TITLE: %s\nBASE_BRANCH: %s\n\nPR_MESSAGE:\n<pr_message>\n%s\n</pr_message>\n' \
    "$title" "$base_branch" "$body" > "$outfile"

  echo "$outfile"
}

if [[ "${BASH_SOURCE[0]}" == "$0" ]]; then
  main "$@"
fi
```

### 5. `fetch-single-comment`: relocate + switch output to temp-file-path (no login/gh changes)

Full new content for `.claude/skills/kxue43-fetch-single-comment/scripts/fetch-single-comment`:

```bash
#!/usr/bin/env bash

set -eu -o pipefail

_pr_comment_url_regex='^https://github\.com/([^/]+)/([^/]+)/pull/[0-9]+/?#(issuecomment-[0-9]+|discussion_r[0-9]+)$'

_render_blockquote() {
  sed -e 's/^/> /' -e 's/^> $/>/'
}

main() {
  if (($# > 0)) && [[ $1 == "-h" ]]; then
    cat <<'EOF'
Usage: fetch-single-comment [-h] COMMENT_URL

Fetch a single GitHub PR comment via the `gh` CLI — either a conversation
comment (URL fragment `#issuecomment-<id>`) or an inline review comment (URL
fragment `#discussion_r<id>`). On success, writes the comment as a markdown
snippet to a temporary file and prints that file's absolute path to stdout.
Auth is assumed to already be set up; on any failure (including auth) prints
`ERROR: <reason>` to stdout instead.

ARGUMENTS:
    COMMENT_URL   Full URL to a GitHub PR comment, e.g.
                  https://github.com/owner/repo/pull/123#issuecomment-456
                  https://github.com/owner/repo/pull/123#discussion_r456

OPTIONS:
    -h          Show this help message
EOF

    return 0
  fi

  if (($# != 1)); then
    echo "ERROR: fetch-single-comment requires exactly one positional argument COMMENT_URL"

    return 0
  fi

  local comment_url=$1

  if ! [[ $comment_url =~ $_pr_comment_url_regex ]]; then
    echo "ERROR: not a recognized PR comment URL: $comment_url"

    return 0
  fi

  local owner=${BASH_REMATCH[1]} repo=${BASH_REMATCH[2]} fragment=${BASH_REMATCH[3]}

  local endpoint
  if [[ $fragment =~ ^issuecomment-([0-9]+)$ ]]; then
    endpoint="repos/$owner/$repo/issues/comments/${BASH_REMATCH[1]}"
  else
    [[ $fragment =~ ^discussion_r([0-9]+)$ ]]
    endpoint="repos/$owner/$repo/pulls/comments/${BASH_REMATCH[1]}"
  fi

  stderr_file=$(mktemp)
  trap 'rm -f "$stderr_file"' EXIT

  local json
  if ! json=$(gh api "$endpoint" 2>"$stderr_file"); then
    echo "ERROR: $(<"$stderr_file")"

    return 0
  fi

  local author body
  author=$(jq -r '.user.login' <<<"$json")
  body=$(jq -r '.body | gsub("\r"; "")' <<<"$json")

  local outfile
  outfile=$(mktemp)

  {
    echo "## PR comment $fragment"
    echo
    if [[ $fragment == discussion_r* ]]; then
      local path line
      path=$(jq -r '.path' <<<"$json")
      line=$(jq -r '.line // .original_line // "(file)"' <<<"$json")
      echo "AUTHOR: $author; PATH: $path; LINE: $line"
    else
      echo "AUTHOR: $author"
    fi
    echo
    _render_blockquote <<<"$body"
  } > "$outfile"

  echo "$outfile"
}

if [[ "${BASH_SOURCE[0]}" == "$0" ]]; then
  main "$@"
fi
```

### 6. Update `.claude/skills/kxue43-pr-review/SKILL.md` call sites and prose

**Step 3 of `start`** (currently lines 67–77) — replace:

```
3. **Fetch PR data** (not jarvis-registry directly). Run via `Bash`:

   ```
   outfile=$(mktemp)
   fetch-pr-data "$pr_url" > "$outfile"
   echo "$outfile"
   ```

   `Read` the printed file path. If its content starts with `ERROR:`, stop immediately and
   report the error to the user verbatim. Otherwise, parse `PR_TITLE`, `BASE_BRANCH`, and
   `PR_MESSAGE` (the content inside `<pr_message>…</pr_message>`) from the file's content.
```

with:

```
3. **Fetch PR data** (not jarvis-registry directly). Run via `Bash`:

   ```
   result=$(${CLAUDE_SKILL_DIR}/scripts/fetch-pr-data "$pr_url")
   ```

   If `$result` starts with `ERROR:`, stop immediately and relay the error reported by the
   script to the user verbatim. Otherwise, `$result` is the absolute path to a file — `Read`
   it and parse `PR_TITLE`, `BASE_BRANCH`, and `PR_MESSAGE` (the content inside
   `<pr_message>…</pr_message>`) from its content.
```

**"Pre-review preparation — link reviewer comments to findings"** in `followup` (currently
lines 263–287) — replace:

```
Extract all finding labels from the `changes_requested` field of the report file's front
matter (e.g. `changes_requested: [C1, M2]` parses to `["C1", "M2"]`) and join with spaces (e.g. `C1 M2`).
Run via `Bash` (not jarvis-registry directly):

```
outfile=$(mktemp)
fetch-pr-comments $pr_url $labels > "$outfile"
echo "$outfile"
```

substituting `$pr_url` with the PR URL and `$labels` with the space-joined label list from
above, passed **unquoted** — this matches the CLI's own positional signature token-for-token;
wrapping them in quotes would collapse everything into a single argument and break label
matching.

`Read` the printed file path. If its content starts with `ERROR:`, stop
immediately and report the error to the user verbatim. Parse the file's content: `LABEL_MAP`
entries show which labels have matching reviewer comments (`FOUND`) and which do not
(`NOT_FOUND`). Each
`## Thread: [Xn]` section is a reviewer comment thread for that label; multiple sections with
the same label are separate threads for the same finding. The thread label matches the finding
label because the reviewer (kxue43) opens each GitHub comment with a first paragraph of
exactly `This is change request [Xn].`, echoing back the finding label assigned during triage.
```

with:

```
Extract all finding labels from the `changes_requested` field of the report file's front
matter (e.g. `changes_requested: [C1, M2]` parses to `["C1", "M2"]`) and join with spaces (e.g. `C1 M2`).
Run via `Bash` (not jarvis-registry directly):

```
result=$(${CLAUDE_SKILL_DIR}/scripts/fetch-pr-comments $pr_url $labels)
```

substituting `$pr_url` with the PR URL and `$labels` with the space-joined label list from
above, passed **unquoted** — this matches the CLI's own positional signature token-for-token;
wrapping them in quotes would collapse everything into a single argument and break label
matching.

If `$result` starts with `ERROR:`, stop immediately and relay the error reported by the script
to the user verbatim — this covers GitHub API failures as well as the script's own `gh` CLI
checks (missing `gh`, an unsupported `gh` version, or not being logged in; the script resolves
the current GitHub login itself, nothing is hardcoded). Otherwise, `$result` is the absolute
path to a file — `Read` it. Parse the file's content: `LABEL_MAP`
entries show which labels have matching reviewer comments (`FOUND`) and which do not
(`NOT_FOUND`). Each
`## Thread: [Xn]` section is a reviewer comment thread for that label; multiple sections with
the same label are separate threads for the same finding. The thread label matches the finding
label because the reviewer (the current `gh`-authenticated GitHub user) opens each GitHub
comment with a first paragraph of exactly `This is change request [Xn].`, echoing back the
finding label assigned during triage.
```

### 7. Update `.claude/skills/kxue43-fetch-single-comment/SKILL.md` call site and prose

Replace the body (currently lines 9–30):

```
Fetch the GitHub PR comment at `$comment_url` — either a conversation comment (URL fragment
`#issuecomment-<id>`) or an inline review comment (URL fragment `#discussion_r<id>`) — via the
`fetch-single-comment` CLI (not the `jarvis-registry` MCP).

**`$comment_url` is required.** If missing, stop and tell the user before doing anything else.

Run via `Bash`:

```
outfile=$(mktemp)
fetch-single-comment "$comment_url" > "$outfile"
echo "$outfile"
```

`Read` the printed file path. If its content starts with `ERROR:`, stop immediately and report
the error to the user verbatim. Otherwise, the file contains a markdown snippet — the comment's
author (and, for inline review comments, the file path and line it's anchored to) followed by
its body as a block quote. If `$instructions` is provided, follow it using the current session
context and the fetched comment as input. Otherwise, infer the task from the session context and
act on it, using the fetched comment as additional input. If no clearer task is evident, default
to assessing whether the comment raises a legitimate, actionable concern against the current
code, and report a verdict.
```

with:

```
Fetch the GitHub PR comment at `$comment_url` — either a conversation comment (URL fragment
`#issuecomment-<id>`) or an inline review comment (URL fragment `#discussion_r<id>`) — via the
bundled `${CLAUDE_SKILL_DIR}/scripts/fetch-single-comment` script (not the `jarvis-registry` MCP).

**`$comment_url` is required.** If missing, stop and tell the user before doing anything else.

Run via `Bash`:

```
result=$(${CLAUDE_SKILL_DIR}/scripts/fetch-single-comment "$comment_url")
```

If `$result` starts with `ERROR:`, stop immediately and relay the error reported by the script
to the user verbatim. Otherwise, `$result` is the absolute path to a file — `Read` it. The file
contains a markdown snippet — the comment's author (and, for inline review comments, the file
path and line it's anchored to) followed by its body as a block quote. If `$instructions` is
provided, follow it using the current session context and the fetched comment as input.
Otherwise, infer the task from the session context and act on it, using the fetched comment as
additional input. If no clearer task is evident, default to assessing whether the comment raises
a legitimate, actionable concern against the current code, and report a verdict.
```

### 8. Delete the now-orphaned `completions/` entries and touch `.keep`

Delete `completions/fetch-pr-comments`, `completions/fetch-pr-data`, `completions/fetch-single-comment`.
`bash-completion` loads these dynamically from `$BASH_COMPLETION_USER_DIR` (set to
`$KXUE43_SUBSTANCE_DIR` in `lib/it-shell.sh:95`) keyed on the command name being typed; once these
three names are off `PATH`, the files can never trigger.

Run `date > .keep` and commit the result, per this repo's documented convention for structural
`bin/` changes — the `shell-cmd-on-change` pre-commit hook (`.pre-commit-config.yaml`) watches
`.keep` and re-runs `set-up.sh` on `post-merge` for other clones, which will clean up their now-
dangling `~/.local/bin` symlinks.

---

## What does NOT change

- `lib/utils.sh` itself is untouched — it's still sourced by other `bin/` scripts and by
  interactive lib files.
- `set-up.sh` requires no code changes (see Change 1).
- `bin/verify-sha`, also used by `kxue43-pr-review/SKILL.md`, is out of scope and stays in `bin/`
  on `PATH` as-is.
- `fetch-pr-data` and `fetch-single-comment` get no `gh`-existence check or login-resolution
  logic — neither references a GitHub login today.
- The `allowed-tools` frontmatter in both `SKILL.md` files stays as the existing unrestricted
  `Bash` grant; it is not narrowed to
  `Bash(${CLAUDE_SKILL_DIR}/scripts/<name> *)`-style patterns.
- `kxue43-fetch-single-comment`'s script is not duplicated into `kxue43-pr-review`'s skill folder
  (see Change 1).

---

## Acceptance Criteria

- [ ] `.claude/skills/kxue43-pr-review/scripts/fetch-pr-data` and
      `.claude/skills/kxue43-pr-review/scripts/fetch-pr-comments` exist, are executable, and
      `bin/fetch-pr-data` / `bin/fetch-pr-comments` no longer exist.
- [ ] `.claude/skills/kxue43-fetch-single-comment/scripts/fetch-single-comment` exists, is
      executable, and `bin/fetch-single-comment` no longer exists.
- [ ] None of the three relocated scripts source `lib/utils.sh` or reference any path outside
      their own skill directory.
- [ ] `fetch-pr-comments` contains no literal `"kxue43"` string; grep confirms it.
- [ ] Running `fetch-pr-comments <pr_url> <label>` with `gh` temporarily removed from `PATH`
      prints `ERROR: gh CLI not found...` to stdout and exits 0.
- [ ] Running `fetch-pr-comments <pr_url> <label>` while logged out of `gh` prints
      `ERROR: not logged into GitHub via gh...` to stdout and exits 0.
- [ ] On a successful run, all three scripts print exactly one line to stdout: the absolute path
      of a file whose content matches what the script used to print directly to stdout.
- [ ] `completions/fetch-pr-comments`, `completions/fetch-pr-data`, and
      `completions/fetch-single-comment` no longer exist.
- [ ] `kxue43-pr-review/SKILL.md` and `kxue43-fetch-single-comment/SKILL.md` invoke their
      scripts via `${CLAUDE_SKILL_DIR}/scripts/<name>` and branch on the captured variable's
      `ERROR:` prefix, with no remaining `outfile=$(mktemp)` / `> "$outfile"` pattern for these
      three scripts.
- [ ] Neither `SKILL.md` file contains the literal string `kxue43` as a GitHub-login reference.
- [ ] `.keep` has been touched and committed alongside these changes.
- [ ] A manual end-to-end run of `/kxue43-pr-review start` against a real PR, and of
      `/kxue43-fetch-single-comment` against a real comment URL, both complete successfully.

---

## Files to Change

| File | Change |
|---|---|
| `bin/fetch-pr-comments` | Deleted (relocated) |
| `bin/fetch-pr-data` | Deleted (relocated) |
| `bin/fetch-single-comment` | Deleted (relocated) |
| `.claude/skills/kxue43-pr-review/scripts/fetch-pr-comments` | New file — relocated script; drops `lib/utils.sh` sourcing; adds `_resolve_login` (gh-existence check + `gh auth status --json` login resolution with version-gate and not-logged-in detection); removes hardcoded `"kxue43"` from the jq program; writes formatted output to a `mktemp` file and prints its path on success |
| `.claude/skills/kxue43-pr-review/scripts/fetch-pr-data` | New file — relocated script; drops `lib/utils.sh` sourcing; writes formatted output to a `mktemp` file and prints its path on success |
| `.claude/skills/kxue43-fetch-single-comment/scripts/fetch-single-comment` | New file — relocated script; drops `lib/utils.sh` sourcing; writes formatted output to a `mktemp` file and prints its path on success |
| `completions/fetch-pr-comments` | Deleted |
| `completions/fetch-pr-data` | Deleted |
| `completions/fetch-single-comment` | Deleted |
| `.claude/skills/kxue43-pr-review/SKILL.md` | Update Step 3 (`start`) and "Pre-review preparation" (`followup`) call sites to the `${CLAUDE_SKILL_DIR}/scripts/...` capture pattern; replace "(kxue43)" with a login-agnostic description |
| `.claude/skills/kxue43-fetch-single-comment/SKILL.md` | Update the call site to the `${CLAUDE_SKILL_DIR}/scripts/...` capture pattern; update the CLI reference text |
| `.keep` | Touch (`date > .keep`) to trigger `set-up.sh` re-run on other clones via the `shell-cmd-on-change` pre-commit hook |

---

## Risk

The `gh auth status --json` version gate (added in gh v2.81.0, 2025-09-25) is the main
correctness risk for teammates on an older `gh`; it's mitigated by detecting the specific
`unknown flag` failure and surfacing a distinct upgrade message rather than misreporting it as
"not logged in" — this repo has no automated tests for `bin/`-style scripts, so this path and
the "logged out" path should both be exercised manually (e.g. `gh auth logout` /
`brew unlink gh` in a scratch shell) before relying on it.

## Out of scope / follow-up

- Scoping `allowed-tools` to `Bash(${CLAUDE_SKILL_DIR}/scripts/<name> *)` patterns to pre-approve
  just these script invocations without granting unrestricted `Bash` — noted during research as
  the docs' recommended pattern for avoiding permission prompts, but not requested here and would
  affect other `Bash` usage in both skills (e.g. `git diff`, `git log`, `verify-sha`).
- `bin/verify-sha` remains a `PATH`-based, `lib/utils.sh`-sourcing script; if it's ever bundled
  into `kxue43-pr-review` for the same portability reason, that's a separate spec.
