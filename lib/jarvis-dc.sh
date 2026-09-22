if [[ -n "${_kxue43_module_set_jarvis_dc+x}" ]]; then
  return
fi

_kxue43_module_set_jarvis_dc=1

source "$(cd "$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")" && pwd)/utils.sh"
source "$(cd "$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")" && pwd)/commands.sh"

jarvis-dc() {
  if (($# == 0)) || [[ "$1" == "-h" ]]; then
    cat <<'EOF'
USAGE: jarvis-dc [-h] [SUBCOMMAND]

SUBCOMMANDS:
    up    [-n|-s] [--local-db]  docker compose up with the right options
    down  [--local-db]          docker compose down with the right options
    logs                        docker logs -f against a container

OPTIONS:
    -h                          Show this help message

    --local-db (up/down)        Use local Mongo/Redis/Weaviate containers instead of the default EKS port-forwarded ones
EOF

    return 0
  fi

  case "$1" in
  up)
    shift 1

    local compose_file="docker-compose.no-db.yml"
    local build_mode="build"
    local -a services=()

    while (($# > 0)); do
      case "$1" in
      -h)
        cat <<'EOF'
Usage: jarvis-dc up [-n|-s] [--local-db] [-h]

docker compose up with the right options.

OPTIONS:
    -n            --no-build
    -s            Pick services via fzf and only rebuild those before starting
    --local-db    Use local Mongo/Redis/Weaviate containers instead of the default EKS port-forwarded ones
    -h            Show this help message
EOF

        return 0
        ;;
      -n)
        build_mode="no-build"
        shift 1
        ;;
      -s)
        build_mode="selective"
        shift 1
        ;;
      --local-db)
        compose_file="docker-compose.kxue43.yml"
        shift 1
        ;;
      *)
        kxue43::log_error "Unknown option $1"

        return 1
        ;;
      esac
    done

    local -a args=("-f" "$compose_file" "--profile" "full" "up" "-d")

    if [[ "$build_mode" == "selective" ]]; then
      mapfile -t services < <(
        docker compose -f "$compose_file" --profile full config --format json 2>/dev/null |
          jq -r '.services | to_entries[] | select(.value.build != null) | .key' |
          fzf -m --height=50% --layout=reverse
      )

      if ((${#services[@]} == 0)); then
        kxue43::log_info "No service selected. Exit"

        return 0
      fi

      args+=("--no-build")
    elif [[ "$build_mode" == "no-build" ]]; then
      args+=("--no-build")
    else
      args+=("--build")
    fi

    local need_artifacts=1

    if [[ "$build_mode" == "no-build" ]]; then
      need_artifacts=0
    elif [[ "$build_mode" == "selective" ]]; then
      need_artifacts=0

      local service
      for service in "${services[@]}"; do
        if [[ "$service" != "registry-frontend" ]]; then
          need_artifacts=1
          break
        fi
      done
    fi

    if ((need_artifacts)); then
      uv run poe -q cleanup-artifacts
    fi

    if ! AWS_PROFILE=ascending-saas-admin aws sts get-caller-identity &>/dev/null; then
      PATH="$HOME/.local/bin:/usr/local/bin:$PATH" aws sso login --sso-session sso-ascending &>/dev/null
    fi

    set-role-env ascending-saas-admin

    if ((need_artifacts)); then
      uv run poe build-artifacts
    fi

    if [[ "$build_mode" == "selective" ]]; then
      docker compose -f "$compose_file" --profile full build "${services[@]}"
    fi

    docker compose "${args[@]}"
    ;;
  down)
    shift 1

    local compose_file="docker-compose.no-db.yml"

    while (($# > 0)); do
      case "$1" in
      -h)
        cat <<'EOF'
Usage: jarvis-dc down [--local-db] [-h]

docker compose down with the right options.

OPTIONS:
    --local-db    Use local Mongo/Redis/Weaviate containers instead of the default EKS port-forwarded ones
    -h            Show this help message
EOF

        return 0
        ;;
      --local-db)
        compose_file="docker-compose.kxue43.yml"
        shift 1
        ;;
      *)
        kxue43::log_error "Unknown option $1"

        return 1
        ;;
      esac
    done

    docker compose -f "$compose_file" --profile full down

    unset AWS_SESSION_TOKEN && unset AWS_SECRET_ACCESS_KEY && unset AWS_ACCESS_KEY_ID && unset AWS_PROFILE && unset AWS_CREDENTIAL_EXPIRATION
    ;;
  logs)
    shift 1

    if (($# > 0)) && [[ $1 == "-h" ]]; then
      cat <<'EOF'
Usage: jarvis-dc logs [-h]

docker logs -f on the fzf-selected container.

OPTIONS:
    -h          Show this help message
EOF

      return 0
    fi

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

_kxue43_jarvis_dc::complete() {
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
  elif ((COMP_CWORD >= 2)) && [[ ${COMP_WORDS[1]} == @(up|down) ]]; then
    local -a flags remaining=()

    if [[ ${COMP_WORDS[1]} == "up" ]]; then
      flags=("-n" "-s" "--local-db")
    else
      flags=("--local-db")
    fi

    if ((COMP_CWORD == 2)); then
      flags+=("-h")
    fi

    # Drop flags already on the command line; -n and -s are mutually exclusive.
    local flag word
    for flag in "${flags[@]}"; do
      for word in "${COMP_WORDS[@]:2:COMP_CWORD-2}"; do
        if [[ $word == "$flag" ]] || [[ $flag == @(-n|-s) && $word == @(-n|-s) ]]; then
          continue 2
        fi
      done

      remaining+=("$flag")
    done

    compgen -V COMPREPLY -W "${remaining[*]}" -- "$2"

    return 0
  elif ((COMP_CWORD == 2)) && [[ $3 == "logs" ]]; then
    COMPREPLY=("-h")

    return 0
  fi
} && complete -o bashdefault -F _kxue43_jarvis_dc::complete jarvis-dc

_kxue43_commands_list+=("jarvis-dc")
