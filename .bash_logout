main() {
  if ! [[ "$KXUE43_PLATFORM" == "Darwin" && -d "${HOME}/.local/share/fnm" ]]; then
    # Clean up symlinks in the $HOME/.local/state/fnm_multishells/ folder on macOS only.
    # On Linux the symlinks already live under a temporary directory.
    return
  fi

  if type -a tmux &>/dev/null && tmux list-sessions &>/dev/null; then
    # Don't clean if there are live tmux sessions.
    return
  fi

  # Disable exit on error for cleanup.
  set +e

  # We are assuming that fnm is on PATH as this script runs in .bash_logout.
  eval "$(fnm env)"

  if [[ -n "${FNM_MULTISHELL_PATH:+x}" ]]; then
    find "$(dirname "${FNM_MULTISHELL_PATH}")/" -type l -name '*_*' -mtime +30 -exec rm {} +
  fi
}

main
