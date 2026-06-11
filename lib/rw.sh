if [[ -n "${_kxue43_module_set_rw+x}" ]]; then
  return
fi

_kxue43_module_set_rw=1

source "$(cd "$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")" && pwd)/utils.sh"

_kxue43_rw::setup() {
  ln -s ../registry-working-docs/ .working-docs

  local files=(.env.no-db .env.mongodb docker-compose.kxue43.yml docker-compose.no-db.yml pyrightconfig.json)
  for file in "${files[@]}"; do
    ln -s ../"${file}" "$file"
  done
}

_kxue43_rw::renew() {
  if ! (
    if ! cd "jarvis-registry"; then
      kxue43::log_error "Failed to cd into jarvis-registry. You are probably not in the correct directory"

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

  mapfile -t worktrees < <(find . -maxdepth 1 -mindepth 1 -type d -name "*-reviews*")

  if ((${#worktrees[@]} == 0)); then
    kxue43::log_info "No worktree directories found"

    return 0
  fi

  worktrees=("${worktrees[@]#./}")

  mapfile -t worktrees < <(printf "%s\n" "${worktrees[@]}" | fzf -m --height=50% --layout=reverse --bind 'load:select-all')

  if ((${#worktrees[@]} == 0)); then
    kxue43::log_info "No worktree selected"

    return 0
  fi

  local target
  for target in "${worktrees[@]}"; do
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
    git -C "jarvis-registry" branch |
      awk '/^  / && !/  parking\// { sub(/^  /, ""); print }' |
      fzf -m --height=50% --layout=reverse
  )

  if ((${#to_delete[@]} == 0)); then
    kxue43::log_info "No branches selected for deletion"

    return 0
  fi

  git -C "jarvis-registry" branch -D "${to_delete[@]}"
}

_kxue43_rw::sync() {
  if [[ "$1" == "-p" ]]; then
    git pull
  fi

  uv sync

  source .venv/bin/activate
}

_kxue43_rw::branch() {
  (
    if ! cd "jarvis-registry"; then
      kxue43::log_error "Failed to cd into jarvis-registry. You are probably not in the correct directory"

      exit 1
    fi

    git branch
  )
}

_kxue43_rw::park() {
  local base
  base="$(basename "$(pwd)")"

  if [[ "$base" == "jarvis-registry" ]]; then
    kxue43::log_error "jarvis-registry is not a parked worktree"

    return 1
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

rw() {
  if (($# == 0)) || [[ $1 == "-h" ]]; then
    cat <<'EOF'
USAGE: rw [-h] [SUBCOMMAND]

SUBCOMMANDS:
    setup         Set up a Jarvis Registry worktree; must be in a worktree folder
    renew         Pull the latest commits on main; rebase parking branches; delete merged branches; must be in the workspace folder
    sync          Perform uv sync and activate the virtual environment; use -p flag to pull down latest commits; must be in a worktree folder
    branch        List all branches with worktree occupancy markings
    park          Checkout the corresponding parking branch of the worktree

OPTIONS:
    -h            Show this help message
EOF

    return 0
  fi
  case "$1" in
  setup)
    _kxue43_rw::setup
    ;;
  renew)
    _kxue43_rw::renew
    ;;
  sync)
    shift 1

    _kxue43_rw::sync "$@"
    ;;
  branch)
    _kxue43_rw::branch
    ;;
  park)
    _kxue43_rw::park
    ;;
  *)
    kxue43::log_error "Unknown subcommand $1"

    return 1
    ;;
  esac
}

_kxue43_rw::complete() {
  local -a opts
  opts=("'-h  (Show help message)'" "'setup  (Setup worktree)'" "'renew  (Renew workspace)'" "'sync  (Sync worktree)'" "'branch  (List branches)'" "'park  (Checkout parking branch)'")

  if ((COMP_CWORD == 1)) && [[ $2 == "" ]]; then
    compgen -V COMPREPLY -W "${opts[*]}"

    return 0
  elif ((COMP_CWORD == 1)) && [[ $2 =~ ^-h?$ ]]; then
    COMPREPLY=("-h")

    return 0
  elif ((COMP_CWORD == 1)); then
    compgen -V COMPREPLY -W "setup renew sync branch park" -- "$2"

    return 0
  fi
} && complete -o bashdefault -F _kxue43_rw::complete rw

_kxue43_commands_list+=("rw")
