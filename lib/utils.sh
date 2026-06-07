# Utility functions for both interactive shell and scripting.

if [[ -n "${_kxue43_module_set_utils+x}" ]]; then
  return
fi

_kxue43_module_set_utils=1

kxue43::log_error() {
  if [[ -t 2 ]]; then
    printf "\033[31m%s\033[0m\n" "$@" >&2
  else
    printf "%s\n" "$@" >&2
  fi
}

kxue43::log_info() {
  if [[ -t 1 ]]; then
    printf "\033[36m%s\033[0m\n" "$@"
  else
    printf "%s\n" "$@"
  fi
}
