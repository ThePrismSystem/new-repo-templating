#!/usr/bin/env bash
# The shell checks. Each job in .github/workflows/shell.yml runs one step; run
# `all` locally before pushing.

usage() {
  cat <<USAGE
Usage: $0 <step>

Steps:
  lint   shellcheck at style severity and shfmt -i 2 -ci over every *.sh and
         *.bats file git doesn't ignore
  test   bats tests/
  all    Every step above
USAGE
}

# Untracked files count too, so a new script is checked before it's added.
shell_files() {
  local file
  while IFS= read -r file; do
    if [[ -f "$file" ]]; then
      printf '%s\n' "$file"
    fi
  done < <(git ls-files --cached --others --exclude-standard -- '*.sh' '*.bats' | sort -u)
}

step_lint() {
  local files=()
  mapfile -t files < <(shell_files)
  if ((${#files[@]} == 0)); then
    echo "No *.sh or *.bats files to check."
    return 0
  fi
  shellcheck --external-sources --severity=style "${files[@]}"
  shfmt -i 2 -ci -d "${files[@]}"
}

step_test() {
  bats tests/
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
