# ------------------------------------------------------------------------
# Environment variables.

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

source "$KXUE43_DOTFILES_DIR/lib/rw.sh"
source "$KXUE43_DOTFILES_DIR/lib/jarvis.sh"

sso-login() {
  aws sso login --sso-session sso-ascending
}
# ------------------------------------------------------------------------
