# Reusable functions for interactive shell (i.e. not scripting).

if [[ -n "${_kxue43_module_set_it_shell+x}" ]]; then
  return
fi

_kxue43_module_set_it_shell=1

source "$(cd "$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")" && pwd)/utils.sh"

_kxue43_it_shell::prompt() {
  local chosen

  select chosen in "$@"; do
    kxue43::log_info "Chose $chosen." >&2

    break
  done

  echo "$chosen"
}

kxue43::prompt_aws_profile() {
  local -a profiles

  mapfile -t profiles < <(grep "^\[profile $1" ~/.aws/config)

  profiles=("${profiles[@]/#\[profile /}")

  profiles=("${profiles[@]/%\]/}")

  _kxue43_it_shell::prompt "${profiles[@]}"
}

kxue43::prompt_aws_region() {
  local -a regions

  if [[ -z "${1:+x}" ]]; then
    regions=(us-east-1 us-west-2)
  else
    mapfile -t -d : regions <<<"$1"
  fi

  _kxue43_it_shell::prompt "${regions[@]}"
}

# Only works on macOS.
kxue43::prompt_jdk_version() {
  local -a versions

  mapfile -t versions < <(/usr/libexec/java_home -V 2>&1 | grep -Eo "^\s*\d+\.\d+\.\d+" | awk '{print $1}')

  _kxue43_it_shell::prompt "${versions[@]}"
}

_kxue43_it_shell::set_path() {
  # For idempotency.
  if [[ -z "${KXUE43_SHELL_INIT+x}" ]]; then
    export KXUE43_SHELL_INIT=1

    local own_path="$HOME/go/bin:$HOME/.cargo/bin:$HOME/.local/bin"

    PATH="$own_path:$PATH"

    if [[ -x /opt/local/bin/port ]]; then
      PATH="/opt/local/bin:/opt/local/sbin:$PATH"
    elif [[ -x /opt/homebrew/bin/brew ]]; then
      export HOMEBREW_FORBIDDEN_FORMULAE="openjdk"

      eval "$(/opt/homebrew/bin/brew shellenv)"
    fi
  fi
}

_kxue43_it_shell::enable_completion() {
  export BASH_COMPLETION_USER_DIR="$KXUE43_SUBSTANCE_DIR:$HOME/.local/share/bash-completion"

  if [[ -x /opt/homebrew/bin/brew ]]; then
    source /opt/homebrew/etc/profile.d/bash_completion.sh

    source /opt/homebrew/etc/bash_completion.d/git-prompt.sh
  elif [[ -x /opt/local/bin/port ]]; then
    source /opt/local/etc/profile.d/bash_completion.sh

    source /opt/local/share/git/git-prompt.sh

    # Activate completion manually for AWS CLI because it's not installed by port.
    complete -C '/usr/local/bin/aws_completer' aws
  elif [[ "$(hostname)" == "fedora" ]]; then
    # On Fedora Server, this file doesn't seem to be automatically sourced.
    source /etc/profile.d/bash_completion.sh

    source /usr/share/git-core/contrib/completion/git-prompt.sh

    # Activate completion for uv and uvx.
    eval "$(uv generate-shell-completion bash)"
    eval "$(uvx --generate-shell-completion bash)"

    PS1='\[\033[94m\]\u@\h: \[\033[96m\]\w\[\033[93m\]$(__git_ps1 " (%s)")\n$(if [ $? -eq 0 ]; then echo -e "\[\033[92m\]\U2714"; else echo -e "\[\033[91m\]\U2718"; fi)\[\033[0m\]\$ '

    return 0
  fi

  PS1='\[\033[94m\]\u@\t: \[\033[96m\]\w\[\033[93m\]$(__git_ps1 " (%s)")\n$(if [ $? -eq 0 ]; then echo -e "\[\033[92m\]\U2714"; else echo -e "\[\033[91m\]\U2718"; fi)\[\033[0m\]\$ '
}

_kxue43_it_shell::shell_integration() {
  export FZF_CTRL_T_OPTS="
  --walker-skip .git,.venv,node_modules,target
  --preview 'bat -n --color=always {}'
  --bind 'ctrl-/:change-preview-window(down|hidden|)'"

  eval "$(fzf --bash)"
}

_kxue43_it_shell::activate_fnm() {
  # FNM is not used in devcontainers.
  if [[ "$(whoami)" == "vscode" ]]; then
    return 0
  fi

  if [[ -z "${KXUE43_SHELL_INIT+x}" ]]; then
    eval "$(fnm env --use-on-cd --shell bash)"
  else
    # Trim the duplicate fnm item in the middle of PATH if exists.
    PATH=$(sed -E -e 's/:[^:]+fnm_multishells[^:]+//' -e 's/[^:]+fnm_multishells[^:]+://' <<<"$PATH")

    # Then activate fnm again, for the use-on-cd effect.
    eval "$(fnm env --use-on-cd --shell bash)"
  fi
}

_kxue43_it_shell::set_man_pager() {
  export MANPAGER="sh -c 'col -b -x | nvim -c \"set ft=man nonu nomodifiable\" -R - '"

  # The MANPAGER above only works with backspace-based formatting,
  # not with the more modern ANSI escape codes. macOS only uses
  # backspace-based formatting. On Linux, we need to set GROFF_NO_SGR
  # to force it.
  [[ "$(uname -s)" == "Linux" ]] && export GROFF_NO_SGR=1
}

kxue43::bash_init() {
  # Used by the `acmd` interactive shell function
  if [[ -z "${_kxue43_commands_list:+x}" ]]; then
    _kxue43_commands_list=()
  fi

  # Perform initialization.
  _kxue43_it_shell::set_path

  _kxue43_it_shell::activate_fnm

  _kxue43_it_shell::enable_completion

  _kxue43_it_shell::shell_integration

  _kxue43_it_shell::set_man_pager
}

kxue43::get_env_prefix() {
  local -n __prefix_var="$1"

  case "$(hostname)" in
  love66* | fedora)
    __prefix_var=kxue43
    ;;
  Kes-MacBook-Pro.*)
    __prefix_var=ascd
    ;;
  LM-*)
    __prefix_var=gd
    ;;
  *)
    if [[ "$(whoami)" == "vscode" ]]; then
      __prefix_var=kxue43
    else
      __prefix_var=""
    fi
    ;;
  esac

  if [[ -n "${KXUE43_WORK_MODE:+x}" ]]; then
    __prefix_var="$KXUE43_WORK_MODE"
  fi
}

kxue43::bash_post_init() {
  local prefix

  kxue43::get_env_prefix "prefix"

  if [[ -z "$prefix" ]]; then
    kxue43::log_error "Unrecognizable hostname '$(hostname)'. No env-specific .bashrc file for it"

    return 1
  elif [[ ! -r "$KXUE43_SUBSTANCE_DIR/profile/${prefix}.bashrc" ]]; then
    kxue43::log_error "Env-specific .bashrc file '${prefix}.bashrc' does not exist on host '$(hostname)'."

    return 1
  fi

  # Source env-specific bashrc file.
  source "$KXUE43_SUBSTANCE_DIR/profile/${prefix}.bashrc"
}
