# Utility functions for both interactive shell and scripting.

if [[ -n "${_sei_module_set_utils+x}" ]]; then
  return
fi

_sei_module_set_utils=1

sei::log_error() {
  if [[ -t 2 ]]; then
    printf "\033[31m%s\033[0m\n" "$@" >&2
  else
    printf "%s\n" "$@" >&2
  fi
}

sei::log_info() {
  if [[ -t 1 ]]; then
    printf "\033[36m%s\033[0m\n" "$@"
  else
    printf "%s\n" "$@"
  fi
}

sei::get_env_prefix() {
  local -n __prefix_var="$1"

  case "$(hostname)" in
  love66*)
    __prefix_var=sei
    ;;
  fedora)
    __prefix_var=fedora
    ;;
  Kes-MacBook-Pro.*)
    __prefix_var=ascd
    ;;
  LM-*)
    __prefix_var=gd
    ;;
  *)
    if [[ "$(whoami)" == "vscode" ]]; then
      __prefix_var=sei
    else
      __prefix_var=""
    fi
    ;;
  esac

  if [[ -n "${SEI_WORK_MODE:+x}" ]]; then
    __prefix_var="$SEI_WORK_MODE"
  fi
}
