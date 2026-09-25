if [[ -n "${_sei_module_set_acmd+x}" ]]; then
  return
fi

_sei_module_set_acmd=1

source "$(cd "$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")" && pwd)/utils.sh"

_sei_acmd::scan_functions_file() {
  local file="$1"
  awk -v file="$file" '
    /^[a-zA-Z0-9-]+\(\) \{$/ {
      name = $0; sub(/\(\) \{$/, "", name); start = NR
    }
    start > 0 && /^\}$/ {
      printf "%s\t%s\t%d:%d\n", name, file, start, NR; start = 0
    }
  ' "$file"
}

_sei_acmd::scan_aliases_file() {
  local file="$1"
  local linenum content name
  while IFS=: read -r linenum content; do
    name="${content#alias }"
    name="${name%%=*}"
    printf "%s\t%s\t%d:%d\n" "$name" "$file" "$linenum" "$linenum"
  done < <(grep -nE "^alias [a-zA-Z0-9-]+=" "$file")
}

_sei_acmd::find_eof_range() {
  local file="$1" func_name="$2"
  local -i linenum=0 a=0 eof_start=0
  local line
  while IFS= read -r line; do
    ((++linenum))
    if ((a == 0)) && [[ "$line" == "${func_name}() {" ]]; then
      a=$linenum
    elif ((a > 0 && eof_start == 0)) && [[ "$line" == *"<<'EOF'" ]]; then
      eof_start=$((linenum + 1))
    elif ((eof_start > 0)) && [[ "$line" == "EOF" ]]; then
      printf "%d:%d\n" "$eof_start" "$((linenum - 1))"
      return 0
    fi
  done <"$file"
  if ((a > 0)); then
    printf "%d:%d\n" "$a" "$((a + 5))"
  fi
}

_sei_acmd::scan_bin_script() {
  local file="$1"
  local name range
  name=$(basename "$file")
  range=$(_sei_acmd::find_eof_range "$file" "main")
  [[ -n "$range" ]] && printf "%s\t%s\t%s\n" "$name" "$file" "$range"
}

_sei_acmd::scan_lib_command() {
  local file="$1" cmd="$2"
  local range
  range=$(_sei_acmd::find_eof_range "$file" "$cmd")
  [[ -n "$range" ]] && printf "%s\t%s\t%s\n" "$cmd" "$file" "$range"
}

_sei_acmd::build_cache() {
  local cache_file="$SEI_SUBSTANCE_DIR/_acmd_cache"
  local tmp_file
  tmp_file=$(mktemp)

  _sei_acmd::scan_functions_file "$SEI_SUBSTANCE_DIR/lib/commands.sh" >>"$tmp_file"
  _sei_acmd::scan_aliases_file "$SEI_SUBSTANCE_DIR/lib/aliases.sh" >>"$tmp_file"

  local prefix
  sei::get_env_prefix "prefix"
  local profile_file="$SEI_SUBSTANCE_DIR/profile/${prefix}.bashrc"
  if [[ -r "$profile_file" ]]; then
    _sei_acmd::scan_functions_file "$profile_file" >>"$tmp_file"
    _sei_acmd::scan_aliases_file "$profile_file" >>"$tmp_file"
  fi

  local script
  for script in "$SEI_SUBSTANCE_DIR/bin/"*; do
    [[ -x "$script" ]] && _sei_acmd::scan_bin_script "$script" >>"$tmp_file"
  done

  local cmd lib_file
  # shellcheck disable=SC2154
  for cmd in "${_sei_commands_list[@]}"; do
    lib_file="$SEI_SUBSTANCE_DIR/lib/${cmd}.sh"
    [[ -r "$lib_file" ]] && _sei_acmd::scan_lib_command "$lib_file" "$cmd" >>"$tmp_file"
  done

  sort "$tmp_file" -o "$tmp_file"
  mv "$tmp_file" "$cache_file"
}

_sei_acmd::check_cache() {
  local cache_file="$SEI_SUBSTANCE_DIR/_acmd_cache"
  if [[ ! -f "$cache_file" ]] ||
    (($(date +%s) - $(date -r "$cache_file" +%s) > 43200)); then
    _sei_acmd::build_cache
  fi
}

acmd() {
  if (($# == 0)) || [[ $1 == "-h" ]]; then
    cat <<'EOF'
USAGE: acmd [-h] [-l] [-p] [-d]

Invoke via `<C-x>l` to open the fzf picker.

OPTIONS:
    -l            List all commands
    -p            Open fzf picker with preview
    -d            Delete the command cache
    -h            Show this help message
EOF

    return 0
  elif ! [[ "$1" == @(-l|-p|-d) ]]; then
    sei::log_error "Unknown argument $1"

    return 1
  fi

  local cache_file="$SEI_SUBSTANCE_DIR/_acmd_cache"

  if [[ "$1" == "-d" ]]; then
    rm -f "$cache_file"

    return 0
  fi

  _sei_acmd::check_cache

  if [[ "$1" == "-l" ]]; then
    cut -f1 "$cache_file" | column -c "$(tput cols)" -x
  elif [[ "$1" == "-p" ]]; then
    local selected
    selected=$(
      fzf --height=60% --layout=reverse \
        --delimiter=$'\t' \
        --with-nth=1 \
        --bind='ctrl-/:change-preview-window(down|hidden|)' \
        --preview='bat --color=always --line-range {3} {2}' \
        <"$cache_file"
    )

    if [[ -n "$selected" ]]; then
      READLINE_LINE="${selected%%$'\t'*} "
      READLINE_POINT=${#READLINE_LINE}
    fi
  fi
}

_sei_acmd::complete() {
  if ((COMP_CWORD == 1)); then
    compgen -V COMPREPLY -W "-l -p -d -h" -- "$2"

    return 0
  fi
} && complete -o bashdefault -F _sei_acmd::complete acmd

_sei_commands_list+=("acmd")

# Triggered only in interactive shells
if [[ $- == *i* ]]; then
  # Only shell functions invoked via `bind -x` can effectively modify READLINE_LINE and READLINE_POINT.
  bind -x '"\C-xl": acmd -p'
fi
