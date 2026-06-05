# ------------------------------------------------------------------------
source "$(cd "$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")" && pwd)/utils.sh"
# ------------------------------------------------------------------------
# Secret environment variables.

# Source credentials from untracked file if exists.
[[ -r "$KXUE43_DOTFILES_DIR/creds.bashrc" ]] && source "$KXUE43_DOTFILES_DIR/creds.bashrc"
# ------------------------------------------------------------------------
# Environment variables.

# Java settings.
if [[ "$KXUE43_PLATFORM" == "Darwin" ]]; then
  JAVA_HOME=$(/usr/libexec/java_home -v 21)
  export JAVA_HOME
fi

# Make tmux+NeoVim work over SSH
export LANG=en_US.UTF-8
export LC_ALL=en_US.UTF-8

# ASCENDING AWS profiles and regions.
export KXUE43_AWS_PROFILE_PREFIX="ascending"
export KXUE43_AWS_REGIONS="us-east-1"
# ------------------------------------------------------------------------
# Aliases.

alias gs='git status'
alias nk9s='tmux new -s k9s'
alias kjd='k9s -n jarvis-demo'
alias gjrw='cd ~/projects/jarvis-registry-workspace/'
# ------------------------------------------------------------------------
# Functions.
#
source "$KXUE43_DOTFILES_DIR/rw.sh"

sso-login() {
  aws sso login --sso-session sso-ascending
}

jarvis-logs() {
  local namespace
  namespace="$(printf "%s\n" "jarvis-demo" "jarvis" | fzf --height=50% --layout=reverse)"

  if [[ -z "$namespace" ]]; then
    kxue43::log_info "No namespace selected. Exit"

    return 0
  fi

  local -a pods
  mapfile -t pods < <(kubectl -n "$namespace" get pods -o name)

  pods=("${pods[@]#"pod/"}")

  local pod
  pod="$(printf "%s\n" "${pods[@]}" | fzf --height=50% --layout=reverse)"

  if [[ -z "$pod" ]]; then
    kxue43::log_info "No pod selected. Exit"

    return 0
  fi

  local since

  read -r -p "Enter --since value (empty means no use): " since

  local follow

  read -r -p "Follow stream? [Y/n] " follow

  follow="${follow:-Y}"

  local dest

  if ! [[ "$follow" =~ ^[Yy]$ ]]; then
    read -r -p "Enter destination file path (empty means stdout): " dest
  fi

  local -a args=(-n "$namespace" logs "$pod")

  [[ -n "$since" ]] && args+=(--since "$since")

  if [[ "$follow" =~ ^[Yy]$ ]]; then
    kubectl "${args[@]}" -f
  elif [[ -n "$dest" ]]; then
    kubectl "${args[@]}" >>"$dest"
  else
    kubectl "${args[@]}"
  fi
}

jarvis-ldc() {
  if (($# == 0)) || [[ "$1" == "-h" ]]; then
    cat <<EOF
USAGE: jarvis-ldc [-h] [SUBCOMMAND]

SUBCOMMANDS:
    up    [-n]     docker compose up with the right options
    down           docker compose down with the right options

OPTIONS:
    -h             Show this help message
EOF

    return 0
  fi

  case "$1" in
  up)
    shift 1

    local -a args=("-f" "docker-compose.no-db.yml" "--profile" "full" "up" "-d")

    if [[ "$1" == "-n" ]]; then
      args+=("--no-build")
    else
      args+=("--build")
    fi

    docker compose "${args[@]}"
    ;;
  down)
    docker compose -f docker-compose.no-db.yml --profile full down
    ;;
  *)
    kxue43::log_error "Unknown subcommand $1"

    return 1
    ;;
  esac
}
# ------------------------------------------------------------------------
