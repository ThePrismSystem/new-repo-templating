#!/usr/bin/env bash
# The Lua checks. Each job in .github/workflows/lua.yml runs one step; run
# `all` locally before pushing. Needs luacheck, lua-language-server, busted,
# luacov and luacov-reporter-lcov on PATH.

usage() {
  cat <<USAGE
Usage: $0 <step>

Steps:
  lint   luacheck, and lua-language-server's diagnostics at warning level
  test   busted with luacov, failing under 80% of lines
  all    Every step above
USAGE
}

step_lint() {
  luacheck .
  local logs
  logs="$(mktemp -d)"
  # shellcheck disable=SC2064 # expand $logs now, while it's in scope
  trap "rm -rf '$logs'" RETURN
  lua-language-server --check="$PWD" --checklevel=Warning --check_format=pretty --logpath="$logs"
}

# luacov adds to its stats file, so each run starts from an empty one.
step_test() {
  mkdir -p coverage
  rm -f coverage/luacov.stats.out coverage/lcov.info
  busted --coverage
  luacov
  scripts/lcov-floor.sh coverage/lcov.info 80
}

main() {
  set -euo pipefail
  local step="${1:-}"
  case "$step" in
    lint | test)
      "step_$step"
      ;;
    all)
      local name
      for name in lint test; do
        echo "-- $name"
        "step_$name"
      done
      ;;
    -h | --help)
      usage
      ;;
    *)
      usage >&2
      exit 2
      ;;
  esac
}

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
  main "$@"
fi
