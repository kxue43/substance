if [[ -n "${_kxue43_module_set_ta+x}" ]]; then
  return
fi

_kxue43_module_set_ta=1

source "$(cd "$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")" && pwd)/utils.sh"

ta() {
  if (($# > 0)) && [[ $1 == "-h" ]]; then
    cat <<'EOF'
Usage: ta [-h] [SESSION_NAME]

Attach to a Tmux session.

ARGUMENTS:
    SESSION_NAME     Name of the session

OPTIONS:
    -h               Show this help message
EOF

    return 0
  fi

  if (($# == 0)); then
    kxue43::log_error "ta requires at least one argument."

    return 1
  fi

  tmux attach-session -t "$1"
}

_kxue43_ta::complete() {
  if ! tmux list-sessions &>/dev/null; then
    return 0
  fi

  if ((COMP_CWORD == 1)); then
    local -a sessions
    mapfile -t sessions < <(tmux list-sessions -F '#{session_name}')

    compgen -V COMPREPLY -W "${sessions[*]}" -- "$2"

    return 0
  fi
} && complete -o bashdefault -F _kxue43_ta::complete ta

_kxue43_commands_list+=("ta")
