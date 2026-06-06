if [[ -n "${_kxue43_module_set_jarvis+x}" ]]; then
  return
fi

_kxue43_module_set_jarvis=1

source "$(cd "$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")" && pwd)/utils.sh"

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
    logs           docker logs -f against a container

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
  logs)
    local container
    container="$(docker ps --format '{{.Names}}' | fzf --height=50% --layout=reverse)"

    if [[ -z "$container" ]]; then
      kxue43::log_info "No container selected. Exit"

      return 0
    fi

    docker logs -f "$container"
    ;;
  *)
    kxue43::log_error "Unknown subcommand $1"

    return 1
    ;;
  esac
}

_kxue43_jarvis::ldc_complete() {
  local -a opts
  opts=("'-h  (Show help message)'" "'up  (docker compose up)'" "'down  (docker compose down)'" "'logs  (docker logs -f)'")

  if ((COMP_CWORD == 1)) && [[ $2 == "" ]]; then
    compgen -V COMPREPLY -W "${opts[*]}"

    return 0
  elif ((COMP_CWORD == 1)) && [[ $2 =~ ^-h?$ ]]; then
    COMPREPLY=("-h")

    return 0
  elif ((COMP_CWORD == 1)); then
    compgen -V COMPREPLY -W "up down logs" -- "$2"

    return 0
  elif ((COMP_CWORD == 2)) && [[ $3 == "up" ]] && [[ $2 == "" ]]; then
    COMPREPLY=("-n")

    return 0
  elif ((COMP_CWORD == 2)) && [[ $3 == "up" ]] && [[ $2 =~ ^-n?$ ]]; then
    COMPREPLY=("-n")

    return 0
  fi
} && complete -o bashdefault -F _kxue43_jarvis::ldc_complete jarvis-ldc

_kxue43_commands_list+=("jarvis-logs" "jarvis-ldc")
