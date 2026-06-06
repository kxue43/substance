#!/usr/bin/env bash

set -eu -o pipefail

source "$(cd "$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")" && pwd)/utils.sh"

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
    if [[ -L "$1/$name" ]]; then
      target_now="$(readlink -f "$1/$name")"

      if [[ "$2/$name" -ef "$target_now" ]]; then
        # If already correctly symlinked, continue.
        continue
      else
        kxue43::log_info "$name is symlinked to $target_now. Removing"

        unlink "$1/$name"
      fi
    elif [[ -f "$1/$name" ]]; then
      # If the ln target already exists as a regular file, remove it.
      kxue43::log_info "Removing existing file $name"

      rm "$1/$name"
    fi

    # If execution reaches here, create the correct symlink.
    ln -s "$2/$name" "$1/$name"

    kxue43::log_info "$name has been correctly symlinked"
  done
}

# Ensure link_path is a symlink pointing to target_path. Creates the symlink if absent;
# logs an error if the path exists but is not a symlink or points elsewhere.
# Args:
#   $1: link_path
#   $2: target_path
# Returns: None
_ensure_symlink() {
  local link_path="$1"
  local target_path="$2"
  local target_now

  if [[ -L "$link_path" ]]; then
    target_now="$(readlink -f "$link_path")"

    if ! [[ "$target_now" -ef "$target_path" ]]; then
      kxue43::log_error "$link_path is incorrectly symlinked to $target_now"
    fi
  elif [[ -e "$link_path" ]]; then
    kxue43::log_error "$link_path already exists and is not a symlink"
  else
    kxue43::log_info "Symlinking $link_path to $target_path"

    ln -s "$target_path" "$link_path"
  fi
}

main() {
  # Make necessary directories first.
  mkdir -p "$HOME/.config/ghostty"
  mkdir -p "$HOME/.config/bat"
  mkdir -p "$HOME/.newsboat"
  mkdir -p "$HOME/.w3m"
  mkdir -p "$HOME/.vim"
  mkdir -p "$HOME/.claude/"
  mkdir -p "$HOME/.local/bin"

  local dotfiles_dir
  dotfiles_dir="$(cd "$(dirname "$(readlink "${BASH_SOURCE[0]}")")" && pwd)"

  local -a linked=(
    .bash_logout
    .bash_profile
    .bashrc
    .inputrc
    .gitconfig
    .vimrc
    .gvimrc
    .tmux.conf
    .config/ghostty/config
    .config/bat/config
  )

  _link_files "$HOME" "$dotfiles_dir" "linked"

  linked=(config urls)
  _link_files "$HOME/.newsboat" "$dotfiles_dir/.newsboat" "linked"

  # shellcheck disable=SC2034 # used via nameref
  linked=(bookmark.html config keymap)
  _link_files "$HOME/.w3m" "$dotfiles_dir/.w3m" "linked"

  # Symlinking own Vim plugin scripts
  _ensure_symlink "$HOME/.vim/plugin" "$dotfiles_dir/.vim/plugin/"

  # Symlinking Claude related files and folders.
  _ensure_symlink "$HOME/.claude/skills" "$dotfiles_dir/.claude/skills/"
  _ensure_symlink "$HOME/.claude/agents" "$dotfiles_dir/.claude/agents/"
  _ensure_symlink "$HOME/.claude/CLAUDE.md" "$dotfiles_dir/.claude/CLAUDE.md"
  _ensure_symlink "$HOME/.claude/settings.json" "$dotfiles_dir/.claude/settings.json"

  # settings.local.json must exist in the dotfiles folder because settings.json is symlinked
  if ! [[ -e "$dotfiles_dir/.claude/settings.local.json" ]]; then
    kxue43::log_info "Creating .claude/settings.local.json in dotfiles directory"

    echo '{}' >"$dotfiles_dir/.claude/settings.local.json"
  fi

  local -a binaries

  mapfile -t binaries < <(ls -1 "$dotfiles_dir/bin")

  _link_files "$HOME/.local/bin" "$dotfiles_dir/bin" "binaries"

  mapfile -t binaries < <(find "$HOME/.local/bin" -type l)

  # Clean up symlinks in ~/.local/bin
  for name in "${binaries[@]}"; do
    if [[ ! -x "$(readlink -f "$name")" ]]; then
      kxue43::log_info "Script $name should no longer exist. Removing"

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
}

if [[ "${BASH_SOURCE[0]}" == "$0" ]]; then
  main "$@"
fi
