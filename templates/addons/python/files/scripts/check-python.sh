#!/usr/bin/env bash
# The Python checks. Each job in .github/workflows/python.yml runs one step;
# run `all` locally before pushing. Uses .venv when it exists, otherwise the
# python3 and ruff on PATH, with requirements-dev.txt installed.

usage() {
  cat <<USAGE
Usage: $0 <step>

Steps:
  lint   ruff check and ruff format --check
  test   unittest under coverage.py, failing under 80% (see .coveragerc)
  all    Every step above
USAGE
}

step_lint() {
  ruff check .
  ruff format --check .
}

# Tests import the modules in src/ by name. The XML report for Codecov is
# written whatever the total, and `report` then prints the table and fails
# under the floor.
step_test() {
  PYTHONPATH=src python3 -m coverage run -m unittest discover -s tests
  python3 -m coverage xml --quiet --fail-under=0
  python3 -m coverage report
}

main() {
  set -euo pipefail
  if [[ -x .venv/bin/python3 ]]; then
    PATH="$PWD/.venv/bin:$PATH"
  fi
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
