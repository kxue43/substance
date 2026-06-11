if [[ -n "${_kxue43_module_set_jarvis_logs+x}" ]]; then
  return
fi

_kxue43_module_set_jarvis_logs=1

source "$(cd "$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")" && pwd)/utils.sh"

jarvis-logs() {
  if (($# > 0)) && [[ "$1" == "-h" ]]; then
    cat <<'EOF'
USAGE: jarvis-logs [-h]

Obtain logs of an EKS pod in the jarvis or jarvis-demo namespace of the cluster.

OPTIONS:
    -h             Show this help message
EOF

    return 0
  fi

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

_kxue43_commands_list+=("jarvis-logs")
