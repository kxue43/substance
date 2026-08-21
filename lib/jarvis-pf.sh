if [[ -n "${_kxue43_module_set_jarvis_pf+x}" ]]; then
  return
fi

_kxue43_module_set_jarvis_pf=1

source "$(cd "$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")" && pwd)/utils.sh"

_kxue43_jarvis_pf::auth() {
  if ! AWS_PROFILE=ascending-saas-admin aws sts get-caller-identity &>/dev/null; then
    PATH="$HOME/.local/bin:/usr/local/bin:$PATH" aws sso login --sso-session sso-ascending &>/dev/null
  fi
}

_kxue43_jarvis_pf::get_namespace() {
  if [[ "$1" != "jarvis-demo" ]] && [[ "$1" != "jarvis" ]]; then
    kxue43::log_error "Unknown namespace '$1'. Must be jarvis-demo or jarvis"

    return 1
  fi

  echo "$1"
}

_kxue43_jarvis_pf::open_pf() {
  local output

  if output="$(pgrep -lf "kubectl port-forward -n $1 pod/$2 $3:$4")"; then
    echo "Port-forwarding $3:$4 for $1/$2 already exists."

    kxue43::log_info "${output:-missing pgrep output}"

    return 0
  fi

  AWS_PROFILE=ascending-saas-admin kubectl port-forward -n "$1" "pod/$2" "$3:$4" >/dev/null 2>>"$5" &

  disown
}

_kxue43_jarvis_pf::close_pf() {
  local -a kprocs
  mapfile -t kprocs < <(pgrep -lf "kubectl port-forward -n $1 pod/")

  if ((${#kprocs[@]} == 0)); then
    kxue43::log_info "No existing port-forwarding for $1"

    return 0
  fi

  local line pid command

  for line in "${kprocs[@]}"; do
    pid="$(cut -d' ' -f1 <<<"$line")"
    command="$(cut -d' ' -f2- <<<"$line")"

    if kill "$pid"; then
      printf "Successfully closed port-forwarding "

      kxue43::log_info "$command"
    else
      printf "Failed to close port-forwarding "

      kxue43::log_error "$command"
    fi
  done
}

_kxue43_jarvis_pf::up() {
  local namespace
  if ! namespace="$(_kxue43_jarvis_pf::get_namespace "${1:-jarvis-demo}")"; then
    return 1
  fi

  _kxue43_jarvis_pf::auth

  local stderr_log
  stderr_log="$(mktemp)"

  _kxue43_jarvis_pf::open_pf "$namespace" mongodb-0 27018 27017 "$stderr_log"
  _kxue43_jarvis_pf::open_pf "$namespace" redis-0 27019 6379 "$stderr_log"
  _kxue43_jarvis_pf::open_pf "$namespace" weaviate-0 27020 8080 "$stderr_log"
  _kxue43_jarvis_pf::open_pf "$namespace" weaviate-0 50051 50051 "$stderr_log"

  # Give the backgrounded kubectl processes time to start before pgrep counts them
  # and before checking whether any of them wrote to stderr.
  sleep 1

  if [[ -s "$stderr_log" ]]; then
    kxue43::log_error "Some port-forwarding commands reported errors; check $stderr_log"
  fi

  local -a kprocs
  mapfile -t kprocs < <(pgrep -lf "kubectl port-forward -n $namespace pod/")

  local line command

  if ((${#kprocs[@]} == 4)); then
    printf "\nSuccessfully started all four port-forwarding:\n"

    for line in "${kprocs[@]}"; do
      command="$(cut -d' ' -f2- <<<"$line")"

      kxue43::log_info "$command"
    done
  else
    printf "\nOnly started %s port-forwarding:\n" "${#kprocs[@]}"

    for line in "${kprocs[@]}"; do
      kxue43::log_error "$line"
    done

    return 1
  fi
}

_kxue43_jarvis_pf::down() {
  local namespace
  if ! namespace="$(_kxue43_jarvis_pf::get_namespace "${1:-jarvis-demo}")"; then
    return 1
  fi

  _kxue43_jarvis_pf::close_pf "$namespace"
}

_kxue43_jarvis_pf::ls() {
  local namespace
  if ! namespace="$(_kxue43_jarvis_pf::get_namespace "${1:-jarvis-demo}")"; then
    return 1
  fi

  local -a kprocs
  mapfile -t kprocs < <(pgrep -lf "kubectl port-forward -n $namespace pod/")

  if ((${#kprocs[@]} == 0)); then
    kxue43::log_info "No existing port-forwarding for $namespace"

    return 0
  fi

  printf "Port-forwardings for %s:\n" "$namespace"

  local line
  for line in "${kprocs[@]}"; do
    kxue43::log_info "$line"
  done
}

jarvis-pf() {
  if (($# == 0)) || [[ "$1" == "-h" ]]; then
    cat <<'EOF'
USAGE: jarvis-pf [-h] [SUBCOMMAND]

SUBCOMMANDS:
    up    [namespace]     Set up EKS port-forwarding for Jarvis Registry services
    down  [namespace]     Tear down EKS port-forwarding for Jarvis Registry services
    ls    [namespace]     List existing EKS port-forwarding for Jarvis Registry services

OPTIONS:
    -h                    Show this help message
EOF

    return 0
  fi

  case "$1" in
  up)
    shift 1

    if (($# > 0)) && [[ $1 == "-h" ]]; then
      cat <<'EOF'
Usage: jarvis-pf up [-h] [NAMESPACE]

Set up EKS port-forwarding for the given NAMESPACE.

ARGUMENTS:
    NAMESPACE:    The namespace to start port-forwarding against. Default to jarvis-demo.

OPTIONS:
    -h            Show this help message
EOF

      return 0
    fi

    _kxue43_jarvis_pf::up "$@"
    ;;
  down)
    shift 1

    if (($# > 0)) && [[ $1 == "-h" ]]; then
      cat <<'EOF'
Usage: jarvis-pf down [-h] [NAMESPACE]

Tear down EKS port-forwarding for the given NAMESPACE.

ARGUMENTS:
    NAMESPACE:    The namespace to start port-forwarding against. Default to jarvis-demo.

OPTIONS:
    -h            Show this help message
EOF

      return 0
    fi

    _kxue43_jarvis_pf::down "$@"
    ;;
  ls | list)
    shift 1

    if (($# > 0)) && [[ $1 == "-h" ]]; then
      cat <<'EOF'
Usage: jarvis-pf ls [-h] [NAMESPACE]

List existing EKS port-forwarding for the given NAMESPACE.

ARGUMENTS:
    NAMESPACE:    The namespace to start port-forwarding against. Default to jarvis-demo.

OPTIONS:
    -h          Show this help message
EOF

      return 0
    fi

    _kxue43_jarvis_pf::ls "$@"
    ;;
  *)
    kxue43::log_error "Unknown subcommand $1"

    return 1
    ;;
  esac
}

_kxue43_jarvis_pf::complete() {
  local -a opts
  opts=("'-h  (Show help message)'" "'up  (Set up port-forwarding)'" "'down  (Tear down port-forwarding)'" "'ls  (List port-forwarding)'")

  if ((COMP_CWORD == 1)) && [[ $2 == "" ]]; then
    compgen -V COMPREPLY -W "${opts[*]}"

    return 0
  elif ((COMP_CWORD == 1)) && [[ $2 =~ ^-h?$ ]]; then
    COMPREPLY=("-h")

    return 0
  elif ((COMP_CWORD == 1)); then
    compgen -V COMPREPLY -W "up down ls" -- "$2"

    if ((${#COMPREPLY[@]} == 0)); then
      compgen -V COMPREPLY -W "up down list" -- "$2"
    fi

    return 0
  elif ((COMP_CWORD == 2)) && [[ $2 =~ ^-h?$ ]]; then
    COMPREPLY=("-h")

    return 0
  elif ((COMP_CWORD == 2)) && [[ $2 =~ ^j ]]; then
    compgen -V COMPREPLY -W "jarvis-demo jarvis" -- "$2"

    return 0
  fi
} && complete -o bashdefault -F _kxue43_jarvis_pf::complete jarvis-pf

_kxue43_commands_list+=("jarvis-pf")
