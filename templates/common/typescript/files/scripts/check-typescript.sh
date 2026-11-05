#!/usr/bin/env bash
# The TypeScript checks. Each job in .github/workflows/typescript.yml runs one
# step; run `all` locally before pushing. Needs `pnpm install` first.

usage() {
  cat <<USAGE
Usage: $0 <step>

Steps:
  lint        Prettier, ESLint with zero warnings, and pnpm audit
  typecheck   tsc over the source and the tooling files
  test        Tests with coverage, failing under 80% (see vitest.config.ts)
  quality     knip for unused code and dependencies, cspell
  build       The production build
  all         Every step above

Set SKIP_AUDIT=1 to leave out pnpm audit when an advisory has no fix yet.
USAGE
}

step_lint() {
  pnpm format
  pnpm lint
  if [[ "${SKIP_AUDIT:-}" != "1" ]]; then
    pnpm audit --audit-level moderate
  fi
}

step_typecheck() {
  pnpm typecheck
}

# A project with integration tests keeps them out of the coverage run through
# a test:unit:coverage script; otherwise test:coverage runs everything.
step_test() {
  if node -e 'process.exit(require("./package.json").scripts["test:unit:coverage"] ? 0 : 1)'; then
    pnpm test:unit:coverage
  else
    pnpm test:coverage
  fi
}

step_quality() {
  pnpm knip
  pnpm spell
}

step_build() {
  pnpm build
}

main() {
  set -euo pipefail
  local step="${1:-}"
  case "$step" in
    lint | typecheck | test | quality | build)
      "step_$step"
      ;;
    all)
      local name
      for name in lint typecheck test quality build; do
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
