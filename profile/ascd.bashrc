# ------------------------------------------------------------------------
# Environment variables.

# ASCENDING AWS profiles and regions.
export KXUE43_AWS_PROFILE_PREFIX="ascending"
export KXUE43_AWS_REGIONS="us-east-1"
# ------------------------------------------------------------------------
# Aliases.

alias gs='git status'
# ------------------------------------------------------------------------
# Functions.

source "$KXUE43_SUBSTANCE_DIR/lib/rw.sh"
source "$KXUE43_SUBSTANCE_DIR/lib/jarvis-logs.sh"
source "$KXUE43_SUBSTANCE_DIR/lib/jarvis-dc.sh"

sso-login() {
  PATH="/opt/homebrew/bin:/usr/local/bin:$PATH" aws sso login --sso-session sso-ascending
}

kjd() {
  export AWS_PROFILE=ascending-saas-admin

  if ! aws sts get-caller-identity &>/dev/null; then
    PATH="/opt/homebrew/bin:/usr/local/bin:$PATH" aws sso login --sso-session sso-ascending
  fi

  k9s -n jarvis-demo
}

gjrw() {
  cd "$HOME/projects/jarvis-registry-workspace/" || return 1

  gt jarvis-registry-workspace
}
# ------------------------------------------------------------------------
