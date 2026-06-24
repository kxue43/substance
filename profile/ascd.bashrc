# ------------------------------------------------------------------------
# Environment variables.

# ASCENDING AWS profiles and regions.
export KXUE43_AWS_PROFILE_PREFIX="ascending"
export KXUE43_AWS_REGIONS="us-east-1"
# ------------------------------------------------------------------------
# Aliases.

alias gs='git status'
alias kjd='k9s -n jarvis-demo'
alias gjrw='cd ~/projects/jarvis-registry-workspace/'
# ------------------------------------------------------------------------
# Functions.

source "$KXUE43_SUBSTANCE_DIR/lib/rw.sh"
source "$KXUE43_SUBSTANCE_DIR/lib/jarvis-logs.sh"
source "$KXUE43_SUBSTANCE_DIR/lib/jarvis-dc.sh"

sso-login() {
  aws sso login --sso-session sso-ascending
}
# ------------------------------------------------------------------------
