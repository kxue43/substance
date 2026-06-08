# -----------------------------------------------------------------------
# Locate substance directory
if [[ -z "${KXUE43_SUBSTANCE_DIR:+x}" ]]; then
  KXUE43_SUBSTANCE_DIR="$(cd "$(dirname "$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")")" && pwd)"

  export KXUE43_SUBSTANCE_DIR
fi
# -----------------------------------------------------------------------
# Source personal library functions.
source "$KXUE43_SUBSTANCE_DIR/lib/it-shell.sh"
# -----------------------------------------------------------------------
# Initialization

kxue43::bash_init
trap 'kxue43::bash_post_init; trap - RETURN' RETURN
# ------------------------------------------------------------------------
# Environment variables

# Make GPG correctly cache passphrase on VS Code terminal
GPG_TTY=$(tty)
export GPG_TTY

# C-x C-e invokes Vim on the current command line.
# VSCode integrated terminal has some problem with NeoVim.
export EDITOR=vim
# ------------------------------------------------------------------------
# Load aliases for interactive use.
source "$KXUE43_SUBSTANCE_DIR/lib/aliases.sh"
# ------------------------------------------------------------------------
# Load custom commands for interactive use.
source "$KXUE43_SUBSTANCE_DIR/lib/commands.sh"
source "$KXUE43_SUBSTANCE_DIR/lib/cplan.sh"
source "$KXUE43_SUBSTANCE_DIR/lib/acmd.sh"
# ------------------------------------------------------------------------
