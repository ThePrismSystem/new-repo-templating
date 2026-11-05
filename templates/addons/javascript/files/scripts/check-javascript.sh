#!/usr/bin/env bash
# The JavaScript checks. Each job in .github/workflows/javascript.yml runs one
# step; run `all` locally before pushing. Needs `pnpm install` first.

usage() {
  cat <<USAGE
Usage: $0 <step>

Steps:
  lint   Prettier, ESLint with zero warnings, cspell and pnpm audit
  test   node --test with coverage, failing under 80% of lines
  all    Every step above

Set SKIP_AUDIT=1 to leave out pnpm audit when an advisory has no fix yet.
USAGE
}

step_lint() {
  pnpm format
  pnpm lint
  pnpm spell
  if [[ "${SKIP_AUDIT:-}" != "1" ]]; then
    pnpm audit --audit-level moderate
  fi
}

step_test() {
  pnpm test:coverage
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
