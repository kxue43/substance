if [[ -n "${_kxue43_module_set_rcliw+x}" ]]; then
  return
fi

_kxue43_module_set_rcliw=1

source "$(cd "$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")" && pwd)/utils.sh"

_kxue43_rcliw::bootstrap() {
  ln -s ../registry-working-docs/ .working-docs
}

_kxue43_rcliw::renew() {
  if ! (
    if ! cd "jarvis-registry-cli"; then
      kxue43::log_error "Failed to cd into jarvis-registry-cli. You are probably not in the correct directory"

      exit 1
    fi

    git pull

    printf "\n"

    kxue43::log_info "Current git worktree status:"

    git branch

    printf "\n"

    read -r -p "Rebase parking branches? [Y/n] " reply

    [[ "${reply:-Y}" =~ ^[Yy]$ ]] || exit 1
  ); then
    kxue43::log_error "Do nothing. Exit"

    return 1
  fi

  local -a worktrees

  mapfile -t worktrees < <(find . -maxdepth 1 -mindepth 1 -type d -name "cli-*-reviews")

  if ((${#worktrees[@]} == 0)); then
    kxue43::log_info "No worktree directories found"

    return 0
  fi

  worktrees=("${worktrees[@]#./}")

  local target
  for target in "${worktrees[@]}"; do
    if [[ "parking/$(basename "$target")" != "$(git -C "$target" branch --show-current)" ]]; then
      continue
    fi

    if ! git -C "$target" rebase main; then
      git -C "$target" rebase --abort

      kxue43::log_error "Failed to rebase parking branch of worktree ${target} onto main"
    fi
  done

  printf "\n"

  local reply
  read -r -p "Delete merged branches? [Y/n] " reply

  [[ "${reply:-Y}" =~ ^[Yy]$ ]] || return 1

  local -a to_delete
  mapfile -t to_delete < <(
    git -C "jarvis-registry-cli" branch |
      awk '/^  / && !/  parking\// { sub(/^  /, ""); print }' |
      fzf -m --height=50% --layout=reverse --bind 'load:select-all'
  )

  if ((${#to_delete[@]} == 0)); then
    kxue43::log_info "No branches selected for deletion"

    return 0
  fi

  git -C "jarvis-registry-cli" branch -D "${to_delete[@]}"
}

_kxue43_rcliw::sync() {
  if (($# > 0)); then
    if ! git ls-remote --exit-code --heads origin "$1" >/dev/null; then
      kxue43::log_error "The remote branch '$1' does not exist."

      return 1
    fi

    git fetch origin

    git switch "$1"

    git pull
  elif [[ "$(git branch --show-current)" != "parking/$(basename "$(pwd)")" ]]; then
    if git rev-parse --abbrev-ref --symbolic-full-name '@{u}' >/dev/null; then
      git pull
    else
      kxue43::log_info "The current branch does not track any remote one. Skip git pull."
    fi
  fi
}

_kxue43_rcliw::branch() {
  (
    if ! cd "jarvis-registry-cli"; then
      kxue43::log_error "Failed to cd into jarvis-registry-cli. You are probably not in the correct directory"

      exit 1
    fi

    git branch
  )
}

_kxue43_rcliw::park() {
  local base
  base="$(basename "$(pwd)")"

  if [[ "$base" == "jarvis-registry-cli" ]]; then
    if ! git checkout main; then
      kxue43::log_error "Failed to check out the main branch"

      return 1
    fi

    return 0
  fi

  if ! git rev-parse --verify "refs/heads/parking/$base" &>/dev/null; then
    kxue43::log_error "No parking branch named 'parking/$base'"

    return 1
  fi

  if ! git checkout "parking/$base"; then
    kxue43::log_error "Failed to check out parking/$base branch"

    return 1
  fi
}

rcliw() {
  if (($# == 0)) || [[ $1 == "-h" ]]; then
    cat <<'EOF'
USAGE: rcliw [-h] [SUBCOMMAND]

SUBCOMMANDS:
    bootstrap               Bootstrap a Jarvis Registry CLI worktree; must be in a worktree folder
    renew                   Pull the latest commits on main; rebase parking branches; delete merged branches; must be in the workspace folder
    sync        [BRANCH]    Pull from the remote branch or switch and pull; must be in a worktree folder
    branch                  List all branches with worktree occupancy markings
    park                    Checkout the corresponding parking branch of the worktree

OPTIONS:
    -h            Show this help message
EOF

    return 0
  fi
  case "$1" in
  bootstrap)
    _kxue43_rcliw::bootstrap
    ;;
  renew)
    _kxue43_rcliw::renew
    ;;
  sync)
    shift 1

    if (($# > 0)) && [[ $1 == "-h" ]]; then
      cat <<'EOF'
Usage: rcliw sync [-h] [BRANCH]

If BRANCH is given, git switch to this remote branch. Then perform git pull.
Must be used in a git worktree folder.

ARGUMENTS:
    BRANCH      The remote branch to git switch to

OPTIONS:
    -h          Show this help message
EOF

      return 0
    fi

    _kxue43_rcliw::sync "$@"
    ;;
  branch)
    _kxue43_rcliw::branch
    ;;
  park)
    _kxue43_rcliw::park
    ;;
  *)
    kxue43::log_error "Unknown subcommand $1"

    return 1
    ;;
  esac
}

_kxue43_rcliw::complete() {
  local -a opts
  opts=("'-h  (Show help message)'" "'bootstrap  (bootstrap worktree)'" "'renew  (Renew workspace)'" "'sync  (Sync worktree)'" "'branch  (List branches)'" "'park  (Checkout parking branch)'")

  if ((COMP_CWORD == 1)) && [[ $2 == "" ]]; then
    compgen -V COMPREPLY -W "${opts[*]}"

    return 0
  elif ((COMP_CWORD == 1)) && [[ $2 =~ ^-h?$ ]]; then
    COMPREPLY=("-h")

    return 0
  elif ((COMP_CWORD == 1)); then
    compgen -V COMPREPLY -W "bootstrap renew sync branch park" -- "$2"

    return 0
  elif ((COMP_CWORD == 2)) && [[ $3 == "sync" ]] && [[ $2 =~ ^-h?$ ]]; then
    compgen -V COMPREPLY -W "-h" -- "$2"

    return 0
  elif ((COMP_CWORD == 2)) && [[ $3 == "sync" ]]; then
    local -a remote_branches

    mapfile -t remote_branches < <(git for-each-ref --format='%(refname:lstrip=3)' refs/remotes/origin | grep -v '^HEAD$')

    compgen -V COMPREPLY -W "${remote_branches[*]}" -- "$2"

    return 0
  fi
} && complete -o bashdefault -F _kxue43_rcliw::complete rcliw

_kxue43_commands_list+=("rcliw")
