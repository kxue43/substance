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

# Groovy settings.
GROOVY_HOME=$HOME/.local/lib/groovy-4.0.27
export GROOVY_HOME
# ------------------------------------------------------------------------
# Aliases.

alias gs='git status'
# ------------------------------------------------------------------------
# Functions.
#
sso-login() {
  aws sso login --sso-session sso-ascending
}
# ------------------------------------------------------------------------
