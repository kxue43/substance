if [[ -n "${_kxue43_module_set_tn+x}" ]]; then
  return
fi

_kxue43_module_set_tn=1

source "$(cd "$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")" && pwd)/utils.sh"

# Args:
# - $1: Project directory to start nvim in.
# - $2 (optional): Whether to start new Tmux session detached.
_kxue43_tn::create_one() {
  if ! pushd "$1" &>/dev/null; then
    kxue43::log_error "Failed to pushd into '$1'"

    return 1
  fi

  if [[ ${2:-} == "-d" ]]; then
    tmux new-session -s "$(basename "$1")" -d
  else
    tmux new-session -s "$(basename "$1")"
  fi

  if ! popd &>/dev/null; then
    kxue43::log_error "Failed to popd back to CWD"

    return 1
  fi
}

tn() {
  if (($# > 0)) && [[ $1 == "-h" ]]; then
    cat <<'EOF'
Usage: tn [-h] [DIR_NAME]

Create a new Tmux session in directory DIR_NAME.

ARGUMENTS:
    DIR_NAME     Directory to create a new Tmux session in

OPTIONS:
    -h           Show this help message
EOF

    return 0
  fi

  if (($# == 0)); then
    kxue43::log_error "tn requires at least one argument."

    return 1
  fi

  if (($# == 1)); then
    _kxue43_tn::create_one "$1"

    return 0
  fi

  local proj

  for proj in "$@"; do
    _kxue43_tn::create_one "$proj" -d
  done

  tmux list-sessions -F '#{session_name}: #{session_windows}win'
}

_kxue43_tn::complete() {
  compgen -V COMPREPLY -d -- "$2"

  return 0
} && complete -o bashdefault -F _kxue43_tn::complete tn

_kxue43_commands_list+=("tn")
