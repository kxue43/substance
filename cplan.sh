if [[ -n "${_kxue43_module_set_cplan+x}" ]]; then
  return
fi

_kxue43_module_set_cplan=1

source "$(cd "$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")" && pwd)/utils.sh"

_kxue43_cplan::ls() {
  local plans_dir="$HOME/.claude/plans"
  local term_width="${COLUMNS:-80}"

  local bold reset dim cyan
  if [[ -t 1 ]]; then
    bold=$'\033[1m'
    reset=$'\033[0m'
    dim=$'\033[2m'
    cyan=$'\033[36m'
  fi

  # width for the timestamp column
  local ts_width=16

  local -a files
  if [[ -d "$plans_dir" ]]; then
    mapfile -t files < <(ls -t "$plans_dir" 2>/dev/null)
  fi

  # Pre-pass: gather max filename length, all titles, and max title length.
  local max_fname=4 max_title=0 file title
  local -a titles=()

  for file in "${files[@]}"; do
    ((${#file} > max_fname)) && max_fname=${#file}

    title=$(head -1 "$plans_dir/$file" | sed -E 's/^#+ *//')

    titles+=("$title")

    ((${#title} > max_title)) && max_title=${#title}
  done

  # Give the filename column just enough width so the longest title fits on one
  # line; if the longest title is too long for that even with a minimal filename
  # column, fall back to capping at 25 (multi-line mode handles the overflow).
  # 4 is for the dots when capping file name column.
  local available_fname=$((term_width - ts_width - 4 - max_title))

  local fname_width
  if ((available_fname >= max_fname)); then
    fname_width=$max_fname
  elif ((available_fname >= 10)); then
    fname_width=$available_fname
  else
    fname_width=$((max_fname < 25 ? max_fname : 25))
  fi

  local title_width=$((term_width - ts_width - fname_width - 4))
  ((title_width < 15)) && title_width=15

  printf "%s%-${ts_width}s  %-${fname_width}s  %s%s\n" "$bold" "MODIFIED" "FILE" "TITLE" "$reset"

  if ((${#files[@]} == 0)); then
    return 0
  fi

  local idx filepath ts ts_date ts_time fname_disp
  local -a title_lines
  local i tline

  for idx in "${!files[@]}"; do
    file="${files[$idx]}"
    filepath="$plans_dir/$file"

    ts=$(date -r "$filepath" "+%Y-%m-%d %H:%M" 2>/dev/null || stat -c "%y" "$filepath" 2>/dev/null | cut -c1-16)
    ts_date="${ts:0:10}"
    ts_time="${ts:11:5}"

    fname_disp="$file"
    ((${#file} > fname_width)) && fname_disp="${file:0:$((fname_width - 3))}..."

    title="${titles[$idx]}"

    if ((${#title} <= title_width)); then
      printf "%s%-${ts_width}s%s  %s%-${fname_width}s%s  %s\n" "$dim" "$ts" "$reset" "$cyan" "$fname_disp" "$reset" "$title"
    else
      mapfile -t title_lines < <(printf '%s\n' "$title" | fold -s -w "$title_width")

      for ((i = 0; i < ${#title_lines[@]}; i++)); do
        tline="${title_lines[$i]}"
        if ((i == 0)); then
          printf "%s%-${ts_width}s%s  %s%-${fname_width}s%s  %s\n" "$dim" "$ts_date" "$reset" "$cyan" "$fname_disp" "$reset" "$tline"
        elif ((i == 1)); then
          printf "%s%-${ts_width}s%s  %-${fname_width}s  %s\n" "$dim" "$ts_time" "$reset" "" "$tline"
        else
          printf "%-${ts_width}s  %-${fname_width}s  %s\n" "" "" "$tline"
        fi
      done
    fi
  done
}

_kxue43_cplan::rm() {
  local -a plans

  mapfile -t plans < <(
    find "$HOME/.claude/plans/" -maxdepth 1 -type f |
      fzf -m --delimiter=/ --with-nth=-1 --height=50% --layout=reverse --preview 'bat -n --color=always {}' --bind 'ctrl-/:change-preview-window(down|hidden|)'
  )

  if ((${#plans[@]} == 0)); then
    kxue43::log_info "No plan selected"

    return 0
  fi

  rm "${plans[@]}"
}

_kxue43_cplan::pick() {
  local -n __plan_var="$1"

  __plan_var="$(
    find "$HOME/.claude/plans/" -maxdepth 1 -type f |
      fzf --delimiter=/ --with-nth=-1 --height=50% --layout=reverse --preview 'bat -n --color=always {}' --bind 'ctrl-/:change-preview-window(down|hidden|)'
  )"
}

_kxue43_cplan::cp() {
  local plan
  _kxue43_cplan::pick "plan"

  if [[ -z "$plan" ]]; then
    kxue43::log_info "No plan selected"

    return 0
  fi

  local lookup_dir dest_dir

  if [[ -d "spec" && -d "session" ]]; then
    lookup_dir="."
  elif [[ -d ".working-docs" ]]; then
    lookup_dir=".working-docs"
  else
    read -r -p "Enter the destination directory: " dest_dir

    if ! [[ -d "$dest_dir" ]]; then
      kxue43::log_error "'$dest_dir' is not an existing directory"

      return 1
    fi
  fi

  if [[ -z "$dest_dir" ]]; then
    dest_dir="$(
      find -L "$lookup_dir" -maxdepth 1 -mindepth 1 -type d |
        fzf --delimiter=/ --with-nth=-1 --height=50% --layout=reverse --preview 'ls -1t {} | head -8' --bind 'ctrl-/:change-preview-window(down|hidden|)'
    )"
  fi

  local filename
  read -r -p "Enter file name: " filename

  kxue43::log_info "Copy $(basename "$plan") to $dest_dir/$filename"

  local reply
  read -r -p "Continue? [y/N]: " reply

  if [[ ! "${reply:-N}" =~ ^[Yy]$ ]]; then
    kxue43::log_error "Exit without copying"

    return 1
  fi

  cp "$plan" "$dest_dir/$filename"
}

_kxue43_cplan::vi() {
  local plan
  _kxue43_cplan::pick "plan"

  if [[ -z "$plan" ]]; then
    kxue43::log_info "No plan selected"

    return 0
  fi

  nvim "$plan"
}

cplan() {
  if (($# == 0)) || [[ $1 == "-h" ]]; then
    cat <<EOF
USAGE: cplan [-h] [SUBCOMMAND]

SUBCOMMANDS:
    ls         List all Claude Code plan files in a table, with last update timestamp, file name and plan title
    rm         Pick plan files to remove in batch
    cp         Copy a single plan file to a specific destination path
    vi         Open a single plan file in NeoVim

OPTIONS:
    -h         Show this help message
EOF

    return 0
  fi
  case "$1" in
  ls | list)
    _kxue43_cplan::ls
    ;;
  rm | remove)
    _kxue43_cplan::rm
    ;;
  cp | copy)
    _kxue43_cplan::cp
    ;;
  vi | nvim)
    _kxue43_cplan::vi
    ;;
  *)
    kxue43::log_error "Unknown subcommand $1"

    return 1
    ;;
  esac
}

_kxue43_cplan::complete() {
  local -a opts
  opts=("'-h  (Show help message)'" "'ls  (List plans)'" "'rm  (Remove plans)'" "'cp  (Copy a plan)'" "'vi  (Open a plan)'")

  if ((COMP_CWORD == 1)) && [[ $2 == "" ]]; then
    compgen -V COMPREPLY -W "${opts[*]}"

    return 0
  elif ((COMP_CWORD == 1)) && [[ $2 =~ ^-h?$ ]]; then
    COMPREPLY=("-h")

    return 0
  elif ((COMP_CWORD == 1)); then
    compgen -V COMPREPLY -W "ls rm cp vi" -- "$2"

    if ((${#COMPREPLY[@]} == 0)); then
      compgen -V COMPREPLY -W "list remove copy nvim" -- "$2"
    fi

    return 0
  fi
} && complete -o bashdefault -F _kxue43_cplan::complete cplan
