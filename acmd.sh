if [[ -n "${_kxue43_module_set_acmd+x}" ]]; then
  return
fi

_kxue43_module_set_acmd=1

source "$(cd "$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")" && pwd)/utils.sh"

acmd() {
  if (($# == 0)) || [[ $1 == "-h" ]]; then
    cat <<'EOF'
USAGE: acmd [-h] [-l]

Invoke via `<C-x>l` to open the fzf picker.

OPTIONS:
    -l            List all commands
    -h            Show this help message
EOF

    return 0
  elif ! [[ "$1" == @(-l|-p) ]]; then
    kxue43::log_error "Unknown argument $1"

    return 1
  fi

  local -a executables aliases

  # shellcheck disable=SC2154 # this variable is appended to by other files
  executables=("${_kxue43_commands_list[@]}")

  mapfile -t -O "${#executables[@]}" executables < <(grep "^[a-zA-Z0-9-]\+() {" "$KXUE43_DOTFILES_DIR/commands.sh")

  mapfile -t aliases < <(grep "^alias [a-zA-Z0-9-]\+=" "$KXUE43_DOTFILES_DIR/aliases.sh")

  local prefix

  case "$KXUE43_HOSTNAME" in
  Kes-MacBook-Pro.*)
    prefix=ascd
    ;;
  LM-*)
    prefix=gd
    ;;
  *)
    prefix=kxue43
    ;;
  esac

  if [[ -r "$KXUE43_DOTFILES_DIR/${prefix}.bashrc" ]]; then
    mapfile -t -O "${#executables[@]}" executables < <(grep "^[a-zA-Z0-9-]\+() {" "$KXUE43_DOTFILES_DIR/${prefix}.bashrc")

    mapfile -t -O "${#executables[@]}" aliases < <(grep "^alias [a-zA-Z0-9-]\+=" "$KXUE43_DOTFILES_DIR/${prefix}.bashrc")
  fi

  executables=("${executables[@]%() \{}")

  aliases=("${aliases[@]%%=*}")
  aliases=("${aliases[@]#alias }")

  mapfile -t -O "${#executables[@]}" executables < <(ls -1 "$KXUE43_DOTFILES_DIR/bin/")

  if [[ "$1" == "-l" ]]; then
    printf "%s\n" "${executables[@]}" "${aliases[@]}" | sort | column -c "$(tput cols)" -x
  elif [[ "$1" == "-p" ]]; then
    local selected
    selected=$(printf "%s\n" "${executables[@]}" "${aliases[@]}" | sort | fzf --height=~17 --layout=reverse)

    if [[ -n "$selected" ]]; then
      READLINE_LINE="$selected "
      READLINE_POINT=${#READLINE_LINE}
    fi
  fi
}

_kxue43_acmd::complete() {
  if ((COMP_CWORD == 1)); then
    compgen -V COMPREPLY -W "-l -h" -- "$2"

    return 0
  fi
} && complete -o bashdefault -F _kxue43_acmd::complete acmd

_kxue43_commands_list+=("acmd")

# Triggered only in interactive shells
if [[ $- == *i* ]]; then
  # Only shell functions invoked via `bind -x` can effectively modify READLINE_LINE and READLINE_POINT.
  bind -x '"\C-xl": acmd -p'
fi
