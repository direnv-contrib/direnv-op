# Shared setup for the bats tests.
#
# Source it inside a `bash -c` script and call `load_libs`, which defines direnv's stdlib
# (has, log_error, log_status) and then the helpers under test. Tests stub `op` with a shell
# function, so nothing talks to the real service.

LIB_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../lib" && pwd)"

load_libs() {
  local lib
  # direnv prints nothing from log_status/log_error unless a log format is set
  export DIRENV_LOG_FORMAT="%s"
  eval "$(direnv stdlib)"
  for lib in "$LIB_DIR"/*.sh; do
    # shellcheck disable=SC1090
    source "$lib"
  done
}
