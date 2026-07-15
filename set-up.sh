#!/usr/bin/env bash

set -eu -o pipefail

source "$(cd "$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")" && pwd)/lib/utils.sh"

_get_symlink_target() {
  readlink "$1"

  if [[ -e "$1" ]]; then
    return 0
  fi

  return 1
}

# Create symlinks in source_dir and point them to actual files in sink_dir.
# Args:
#   $1: source_dir
#   $2: sink_dir
#   $3: name of the array variable that holds base names
# Returns: None
_link_files() {
  local -n base_names="$3"

  local name target_now

  for name in "${base_names[@]}"; do
    if [[ -L "$1/$name" ]] && ! target_now="$(_get_symlink_target "$1/$name")"; then
      kxue43::log_info "Symlink target $target_now does not exist. Removing symlink"

      unlink "$1/$name"
    elif [[ -L "$1/$name" ]] && [[ "$2/$name" -ef "$target_now" ]]; then
      # If already correctly symlinked, continue.
      continue
    elif [[ -L "$1/$name" ]]; then
      kxue43::log_info "$name is symlinked to $target_now. Removing symlink"

      unlink "$1/$name"
    elif [[ -f "$1/$name" ]]; then
      # If the ln target already exists as a regular file, remove it.
      kxue43::log_info "Removing existing file $name"

      rm "$1/$name"
    fi

    ln -s "$2/$name" "$1/$name"

    kxue43::log_info "$name has been correctly symlinked"
  done
}

# Ensure link_path is a symlink pointing to target_path.
# Creates the symlink if absent; recreate the symlink if target is wrong.
# Logs an error if the path exists but is not a symlink.
# Args:
#   $1: link_path
#   $2: target_path
# Returns: None
_ensure_symlink() {
  local link_path="$1"
  local target_path="$2"
  local target_now

  if [[ -L "$link_path" ]] && ! target_now="$(_get_symlink_target "$link_path")"; then
    kxue43::log_info "Symlink target $target_now does not exist. Removing symlink"

    unlink "$link_path"
  elif [[ -L "$link_path" ]] && [[ "$target_now" -ef "$target_path" ]]; then
    return 0
  elif [[ -L "$link_path" ]]; then
    kxue43::log_info "$link_path is incorrectly symlinked to $target_now. Removing symlink"

    unlink "$link_path"
  elif [[ -e "$link_path" ]]; then
    kxue43::log_error "$link_path already exists and is not a symlink"

    return 0
  fi

  kxue43::log_info "Symlinking $link_path to $target_path"

  ln -s "$target_path" "$link_path"
}

main() {
  # Make necessary directories first.
  mkdir -p "$HOME/.config/ghostty"
  mkdir -p "$HOME/.config/bat"
  mkdir -p "$HOME/.vim"
  mkdir -p "$HOME/.claude/"
  mkdir -p "$HOME/.local/bin"

  local substance_dir
  substance_dir="$(cd "$(dirname "$(readlink "${BASH_SOURCE[0]}")")" && pwd)"

  local prefix
  kxue43::get_env_prefix "prefix"

  local -a linked=(
    .bash_logout
    .bash_profile
    .bashrc
    .gitconfig
    .gvimrc
    .inputrc
    .vimrc
  )

  [[ "$prefix" == "fedora" ]] && linked+=(".tmux.conf")

  _link_files "$HOME" "$substance_dir/dotfiles" "linked"

  # shellcheck disable=SC2034 # used via nameref
  linked=(.config/ghostty/config .config/bat/config)
  _link_files "$HOME" "$substance_dir" "linked"

  # Symlinking nvim folder
  _ensure_symlink "$HOME/.config/nvim" "$substance_dir/nvim/"

  # Symlinking own Vim plugin scripts
  _ensure_symlink "$HOME/.vim/plugin" "$substance_dir/.vim/plugin/"

  # Symlinking Claude related files and folders
  _ensure_symlink "$HOME/.claude/skills" "$substance_dir/.claude/skills/"
  _ensure_symlink "$HOME/.claude/agents" "$substance_dir/.claude/agents/"
  _ensure_symlink "$HOME/.claude/CLAUDE.md" "$substance_dir/.claude/CLAUDE.md"
  _ensure_symlink "$HOME/.claude/settings.json" "$substance_dir/.claude/settings.json"

  # settings.local.json must exist in the substance folder because settings.json is symlinked
  if ! [[ -e "$substance_dir/.claude/settings.local.json" ]]; then
    kxue43::log_info "Creating .claude/settings.local.json in substance directory"

    echo '{}' >"$substance_dir/.claude/settings.local.json"
  fi

  local name

  local -a binaries

  mapfile -t binaries < <(ls -1 "$substance_dir/bin")

  _link_files "$HOME/.local/bin" "$substance_dir/bin" "binaries"

  mapfile -t binaries < <(find "$HOME/.local/bin" -type l)

  # Clean up symlinks in ~/.local/bin
  for name in "${binaries[@]}"; do
    if [[ ! -x "$(readlink "$name")" ]]; then
      kxue43::log_info "Script $name should no longer exist. Removing"

      unlink "$name"
    fi
  done

  local -a dotfiles
  mapfile -t dotfiles < <(find "$HOME" -maxdepth 1 -mindepth 1 -type l)

  # Clean up symlinks to dot files
  for name in "${dotfiles[@]}"; do
    if [[ ! -e "$(readlink "$name")" ]] || [[ "$prefix" != "fedora" && "$name" == "$HOME/.tmux.conf" ]]; then
      kxue43::log_info "Dot file $name should no longer exist. Removing"

      unlink "$name"
    fi
  done

  # Disable Git commit signing in devcontainer.
  if [[ "$(whoami)" == "vscode" && ! -r "$HOME/.gitconfig.override" ]]; then
    cat >"$HOME/.gitconfig.override" <<'EOF'
[user]
	name = kxue43
	email = kxue43@gmail.com
[commit]
	gpgsign = false
[tag]
	gpgSign = false
EOF
  fi

  if ! type pre-commit &>/dev/null; then
    return 0
  fi

  local -a args=()
  [[ -e "$substance_dir/.git/hooks/pre-commit" ]] || args+=("-t" "pre-commit")
  [[ -e "$substance_dir/.git/hooks/post-merge" ]] || args+=("-t" "post-merge")

  if ((${#args[@]} > 0)); then
    pre-commit install "${args[@]}"
  fi
}

if [[ "${BASH_SOURCE[0]}" == "$0" ]]; then
  main "$@"
fi
