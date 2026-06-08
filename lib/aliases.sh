if [[ -n "${_kxue43_module_set_aliases+x}" ]]; then
  return
fi

_kxue43_module_set_aliases=1

alias ls='ls --color=auto'

alias gproj='cd ~/projects'

alias gtemp='cd ~/temp'

alias glearn='cd ~/learning'

alias gascd='cd ~/ascending'

alias gdump='cd ~/temp/dump'

alias rdump='pushd ~/temp >/dev/null ; rm -rf dump && mkdir dump ; popd >/dev/null'

alias venvact='. .venv/bin/activate'

alias clean-aws-cache="unset AWS_SESSION_TOKEN && unset AWS_SECRET_ACCESS_KEY && unset AWS_ACCESS_KEY_ID && unset AWS_CREDENTIAL_EXPIRATION && rm -rf ~/.aws/toolkit-cache && rm -rf ~/.aws/sso/cache && rm -rf ~/.aws/cli/cache && rm -rf ~/.aws/boto/cache"

alias clean-aws-env="unset AWS_SESSION_TOKEN && unset AWS_SECRET_ACCESS_KEY && unset AWS_ACCESS_KEY_ID && unset AWS_REGION && unset AWS_DEFAULT_REGION && unset AWS_PROFILE && unset AWS_CREDENTIAL_EXPIRATION"

alias gci='aws sts get-caller-identity'

alias ls-path='printenv PATH | tr ":" "\n"'

alias subp='pushd "$KXUE43_SUBSTANCE_DIR" >/dev/null && git pull && popd >/dev/null'

if [[ "$(uname -s)" == "Darwin" ]]; then
  alias mvim='open -a MacVim'
fi
