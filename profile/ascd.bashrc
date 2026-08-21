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
source "$KXUE43_SUBSTANCE_DIR/lib/jarvis-pf.sh"

sso-login() {
  PATH="$HOME/.local/bin:/usr/local/bin:$PATH" aws sso login --sso-session sso-ascending
}

kjd() {
  export AWS_PROFILE=ascending-saas-admin

  if ! aws sts get-caller-identity &>/dev/null; then
    PATH="$HOME/.local/bin:/usr/local/bin:$PATH" aws sso login --sso-session sso-ascending
  fi

  k9s -n jarvis-demo
}

gjrw() {
  mkdir -p "$HOME/temp/dump"

  cd "$HOME/temp/dump" || return 1

  gt k9s

  gn "$HOME/projects/jarvis-registry-workspace/registry-working-docs/"

  gn "$HOME/projects/jarvis-registry-workspace"

  printf '\033[H\033[2J'
}
# ------------------------------------------------------------------------
