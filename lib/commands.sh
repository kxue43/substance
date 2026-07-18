if [[ -n "${_kxue43_module_set_commands+x}" ]]; then
  return
fi

_kxue43_module_set_commands=1

source "$(cd "$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")" && pwd)/utils.sh"
source "$(cd "$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")" && pwd)/it-shell.sh"
source "$(cd "$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")" && pwd)/acmd.sh"

subp() {
  git -C "$KXUE43_SUBSTANCE_DIR" pull
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

  # Make sure system AWS CLI (guaranteed to be v2) is used. Sometimes a Python venv might have AWS CLI v1 installed.
  eval "$(PATH="/opt/homebrew/bin:/usr/local/bin:$PATH" aws configure export-credentials --format env --profile "$profile")"

  unset AWS_PROFILE
}

glo() {
  git log --oneline "$@"
}

gsh() {
  git show --name-only "$@"
}

kdiff() {
  git diff --no-index "$1" "$2"
}

gtc() {
  local profile=coverage.out

  go test -race -coverprofile=${profile} "${1:-./...}"

  go tool cover -html=${profile}
}

init-devcon-files() {
  if [[ ! -d "$KXUE43_SUBSTANCE_DIR/.devcontainer" ]]; then
    kxue43::log_error "The $KXUE43_SUBSTANCE_DIR/.devcontainer/ folder does not exist."

    return 1
  fi

  kxue43::log_info "Creating .devcontainer/ folder in the current working directory."

  cp -R "$KXUE43_SUBSTANCE_DIR/.devcontainer/" ./.devcontainer/
}

enter-work-mode() {
  # Enter work mode in the current shell and all sub-processes.
  # Current work mode env prefix is `ascd`.
  KXUE43_WORK_MODE="ascd"

  export KXUE43_WORK_MODE

  kxue43::bash_post_init

  acmd -d
}

if [[ "$(uname -s)" == "Darwin" ]]; then
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
