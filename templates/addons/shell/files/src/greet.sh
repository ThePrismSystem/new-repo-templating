#!/usr/bin/env bash
# Prints a greeting for each name given, or for the world when there are none.

greet() {
  printf 'Hello, %s!\n' "${1:-world}"
}

main() {
  set -euo pipefail
  if (($# == 0)); then
    greet
    return
  fi
  local name
  for name in "$@"; do
    greet "$name"
  done
}

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
  main "$@"
fi
