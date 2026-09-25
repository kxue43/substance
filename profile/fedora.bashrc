# ------------------------------------------------------------------------
# Environment variables.

# ------------------------------------------------------------------------
# Aliases.

alias gs='git status'
# ------------------------------------------------------------------------
# Functions.

source "$SEI_SUBSTANCE_DIR/lib/tn.sh"
source "$SEI_SUBSTANCE_DIR/lib/ta.sh"

tl() {
  tmux list-sessions -F '#{session_name}: #{session_windows}win'
}
# ------------------------------------------------------------------------
