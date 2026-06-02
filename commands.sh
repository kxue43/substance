if [[ -n "${_kxue43_module_set_commands+x}" ]]; then
  return
fi

_kxue43_module_set_commands=1

source "$(cd "$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")" && pwd)/utils.sh"

list-all() {
  local -a executables aliases

  # More complex interactive shell functions should be in their own `command_name.sh` file,
  # which is sourced in `.bashrc` or `.${env}.bashrc` directly.
  # shellcheck disable=SC2154 # this variable is appended to by other files
  executables=("${_kxue43_commands_list[@]}")

  mapfile -t -O "${#executables[@]}" executables < <(grep "^[a-zA-Z0-9-]\+() {" "$KXUE43_DOTFILES_DIR/commands.sh")

  mapfile -t aliases < <(grep "^alias [a-zA-Z0-9-]\+=" "$KXUE43_DOTFILES_DIR/aliases.sh")

  local prefix

  case "$KXUE43_HOSTNAME" in
  Kes-MacBook-Pro.*)
    prefix=ascd
    ;;
  LM-*)
    prefix=gd
    ;;
  *)
    prefix=kxue43
    ;;
  esac

  if [[ -r "$KXUE43_DOTFILES_DIR/${prefix}.bashrc" ]]; then
    mapfile -t -O "${#executables[@]}" executables < <(grep "^[a-zA-Z0-9-]\+() {" "$KXUE43_DOTFILES_DIR/${prefix}.bashrc")

    mapfile -t -O "${#executables[@]}" aliases < <(grep "^alias [a-zA-Z0-9-]\+=" "$KXUE43_DOTFILES_DIR/${prefix}.bashrc")
  fi

  executables=("${executables[@]%() \{}")

  aliases=("${aliases[@]%%=*}")
  aliases=("${aliases[@]#alias }")

  mapfile -t -O "${#executables[@]}" executables < <(ls -1 "$KXUE43_DOTFILES_DIR/bin/")

  printf "%s\n" "${executables[@]}" "${aliases[@]}" | sort | column -c "$(tput cols)" -x
}

tl() {
  tmux list-sessions -F '#{session_name}: #{session_windows}win'
}

dotfp() {
  kxue43::log_info "Pulling dot-file changes into $KXUE43_DOTFILES_DIR"

  pushd "$KXUE43_DOTFILES_DIR" >/dev/null || return 1

  git pull

  popd >/dev/null || return 1
}

set-aws-region() {
  local region

  if [[ -n "${1:+x}" ]]; then
    region=$1
  else
    region=$(kxue43::prompt_aws_region "$KXUE43_AWS_REGIONS")
  fi

  export AWS_DEFAULT_REGION=$region

  export AWS_REGION=$region
}

ls-aws-env() {
  printenv | grep '^AWS'
}

use-role-profile() {
  if [[ -n "${1:+x}" ]]; then
    export AWS_PROFILE=$1

    return 0
  fi

  AWS_PROFILE=$(kxue43::prompt_aws_profile "$KXUE43_AWS_PROFILE_PREFIX")
  export AWS_PROFILE
}

set-role-env() {
  local profile

  if [[ -n "${1:+x}" ]]; then
    profile=$1
  else
    profile=$(kxue43::prompt_aws_profile "$KXUE43_AWS_PROFILE_PREFIX")
  fi

  eval "$(aws configure export-credentials --format env --profile "$profile")"

  unset AWS_PROFILE
}

glo() {
  git log --oneline "$@"
}

gsh() {
  git show --name-only "$@"
}

my-diff() {
  git diff --no-index "$1" "$2"
}

gtc() {
  local profile=coverage.out

  go test -race -coverprofile=${profile} "${1:-./...}"

  go tool cover -html=${profile}
}

init-devcon-files() {
  if [[ ! -d "$KXUE43_DOTFILES_DIR/.devcontainer" ]]; then
    kxue43::log_error "The $KXUE43_DOTFILES_DIR/.devcontainer/ folder does not exist."

    return 1
  fi

  kxue43::log_info "Creating .devcontainer/ folder in the current working directory."

  cp -R "$KXUE43_DOTFILES_DIR/.devcontainer/" ./.devcontainer/
}

rm-cdk-images() {
  local tags
  mapfile -t tags < <(docker images --filter "reference=cdkasset-*:latest" --format "{{.Repository}}:{{.Tag}}")

  if ((${#tags[@]} == 0)); then
    kxue43::log_info "No existing CDK asset images."

    return 0
  fi

  docker image rm "${tags[@]}"

  mapfile -t tags < <(docker images --filter "reference=*.amazonaws.com/cdk-hnb659fds-*:*" --format "{{.Repository}}:{{.Tag}}")

  if ((${#tags[@]} > 0)); then
    docker image rm "${tags[@]}"
  fi
}

rm-docker-images() {
  local tags
  mapfile -t tags < <(docker images --format "{{.Repository}}:{{.Tag}}" | fzf -m --height=50% --layout=reverse)

  if ((${#tags[@]} == 0)); then
    kxue43::log_info "No image selected."

    return 0
  else
    kxue43::log_info "The following images are selected:"
    kxue43::log_info "${tags[@]}" "\n"
  fi

  docker image rm "${tags[@]}"
}

if [[ "$KXUE43_PLATFORM" == "Darwin" ]]; then
  ls-jdk() {
    /usr/libexec/java_home -V
  }

  set-jdk() {
    local jdk_version

    jdk_version=$(kxue43::prompt_jdk_version)

    JAVA_HOME=$(/usr/libexec/java_home -v "$jdk_version")
    export JAVA_HOME
  }

  user-query() {
    dscl . -read "$HOME" UniqueID PrimaryGroupID NFSHomeDirectory UserShell
  }
fi
