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
#
source "$KXUE43_DOTFILES_DIR/rw.sh"

sso-login() {
  aws sso login --sso-session sso-ascending
}
# ------------------------------------------------------------------------
