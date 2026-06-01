# ------------------------------------------------------------------------
# Secret environment variables.

# Source credentials from untracked file if exists.
[[ -r "$KXUE43_DOTFILES_DIR/creds.bashrc" ]] && source "$KXUE43_DOTFILES_DIR/creds.bashrc"
# ------------------------------------------------------------------------
# Environment variables.

# Java settings.
if [[ "$KXUE43_PLATFORM" == "Darwin" ]]; then
  JAVA_HOME=$(/usr/libexec/java_home -v 21)
  export JAVA_HOME
fi

# Make tmux+NeoVim work over SSH
export LANG=en_US.UTF-8
export LC_ALL=en_US.UTF-8

# ASCENDING AWS profiles and regions.
export KXUE43_AWS_PROFILE_PREFIX="ascending"
export KXUE43_AWS_REGIONS="us-east-1"
# ------------------------------------------------------------------------
# Aliases.

alias gs='git status'
alias nk9s='tmux new -s k9s'
alias kjd='k9s -n jarvis-demo'
alias gjrw='cd ~/projects/jarvis-registry-workspace/'
# ------------------------------------------------------------------------
# Functions.

sso-login() {
  aws sso login --sso-session sso-ascending
}

setup-registry-worktree() {
  ln -s ../registry-working-docs/ .working-docs

  local files=(.env.no-db .env.mongodb docker-compose.kxue43.yml docker-compose.no-db.yml)
  for file in "${files[@]}"; do
    ln -s ../"${file}" "$file"
  done
}

renew-registry-worktree() {
  if ! (
    if ! cd "jarvis-registry"; then
      kxue43::log_error "Failed to cd into jarvis-registry. You are probably not in the correct directory"

      exit 1
    fi

    git pull

    printf "\n"

    kxue43::log_info "Current git worktree status:"

    git branch

    printf "\n"

    read -r -p "Continue? [Y/n] " reply

    [[ "${reply:-Y}" =~ ^[Yy]$ ]] || exit 1
  ); then
    kxue43::log_error "Do nothing. Exit"

    return 1
  fi

  local -a worktrees

  mapfile -t worktrees < <(find . -maxdepth 1 -mindepth 1 -type d -name "*-reviews*")

  if ((${#worktrees[@]} == 0)); then
    kxue43::log_info "No worktree directories found"

    return 0
  fi

  worktrees=("${worktrees[@]#./}")

  mapfile -t worktrees < <(printf "%s\n" "${worktrees[@]}" | fzf -m --height=50% --layout=reverse --bind 'load:select-all')

  if ((${#worktrees[@]} == 0)); then
    kxue43::log_info "No worktree selected"

    return 0
  fi

  local target
  for target in "${worktrees[@]}"; do
    if ! git -C "$target" rebase main; then
      git -C "$target" rebase --abort

      kxue43::log_error "Failed to rebase parking branch of worktree ${target} onto main"
    fi
  done

  printf "\n"

  local reply
  read -r -p "Delete merged branches? [Y/n] " reply

  [[ "${reply:-Y}" =~ ^[Yy]$ ]] || exit 1

  local -a to_delete
  mapfile -t to_delete < <(
    git -C "jarvis-registry" branch |
      awk '/^  / && !/  parking\// { sub(/^  /, ""); print }' |
      fzf -m --height=50% --layout=reverse
  )

  if ((${#to_delete[@]} == 0)); then
    kxue43::log_info "No branches selected for deletion"

    return 0
  fi

  git -C "jarvis-registry" branch -D "${to_delete[@]}"
}

sync-registry-worktree() {
  if [[ "$1" == "-p" ]]; then
    git pull
  fi

  uv sync

  source .venv/bin/activate
}
# ------------------------------------------------------------------------
