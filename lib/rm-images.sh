if [[ -n "${_kxue43_module_set_rm_images+x}" ]]; then
  return
fi

_kxue43_module_set_rm_images=1

source "$(cd "$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")" && pwd)/utils.sh"

_kxue43_rm_images::cdk() {
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

_kxue43_rm_images::docker() {
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

rm-images() {
  if (($# == 0)) || [[ "$1" == "-h" ]]; then
    cat <<'EOF'
USAGE: rm-images [-h] [SUBCOMMAND]

SUBCOMMANDS:
    cdk           Remove CDK asset images
    docker        Select and remove Docker images

OPTIONS:
    -h            Show this help message
EOF

    return 0
  fi

  case "$1" in
  cdk)
    _kxue43_rm_images::cdk
    ;;
  docker)
    _kxue43_rm_images::docker
    ;;
  *)
    kxue43::log_error "Unknown subcommand $1"

    return 1
    ;;
  esac
}

_kxue43_rm_images::complete() {
  local -a opts
  opts=("'-h  (Show help message)'" "'cdk  (Remove CDK asset images)'" "'docker  (Remove Docker images)'")

  if ((COMP_CWORD == 1)) && [[ $2 == "" ]]; then
    compgen -V COMPREPLY -W "${opts[*]}"

    return 0
  elif ((COMP_CWORD == 1)) && [[ $2 =~ ^-h?$ ]]; then
    COMPREPLY=("-h")

    return 0
  elif ((COMP_CWORD == 1)); then
    compgen -V COMPREPLY -W "cdk docker" -- "$2"

    return 0
  fi
} && complete -o bashdefault -F _kxue43_rm_images::complete rm-images

_kxue43_commands_list+=("rm-images")
