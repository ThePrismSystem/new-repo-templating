#!/usr/bin/env bash
# `set -euo pipefail` lives in main() rather than at the top level on purpose:
# tests/verify.bats sources this file, and setting shell options at load time
# would leak errexit and nounset into the bats test shell.

PUBLIC_ONLY_WORKFLOWS=(".github/workflows/codeql.yml" ".github/workflows/gitleaks.yml")

# Fails if setup.sh left any {{PLACEHOLDER}} unsubstituted in the scaffold.
# grep exits 0 when it finds a match, which is the failure case here.
assert_no_placeholders() {
  local dir="$1"
  local hits
  if hits="$(grep -rIn '{{[A-Z_]\+}}' "$dir" \
    --exclude-dir=node_modules --exclude-dir=.git 2>/dev/null)"; then
    echo "FAIL: unsubstituted placeholders in scaffold:" >&2
    echo "$hits" >&2
    return 1
  fi
  return 0
}

# Fails if public-only workflows are missing from a public scaffold,
# or present in a private one.
assert_visibility() {
  local dir="$1"
  local visibility="$2"
  local workflow
  for workflow in "${PUBLIC_ONLY_WORKFLOWS[@]}"; do
    if [[ "$visibility" == "public" ]]; then
      if [[ ! -f "$dir/$workflow" ]]; then
        echo "FAIL: public scaffold is missing $workflow" >&2
        return 1
      fi
    else
      if [[ -f "$dir/$workflow" ]]; then
        echo "FAIL: private scaffold contains $workflow" >&2
        return 1
      fi
    fi
  done
  return 0
}

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

AVAILABLE_FLAVORS=("typescript-node" "typescript-react")
GATE_STEPS=("format" "lint" "typecheck" "__TEST__" "knip" "spell" "build")

KEEP=false
SKIP_AUDIT=false
SELECTED_FLAVORS=()
WORKDIRS=()

usage() {
  cat <<EOF
Usage: $0 [--flavor typescript-node|typescript-react] [--keep] [--skip-audit]

Scaffolds each template flavor into a temporary directory and runs the same
gate the generated project's own CI runs.

Options:
  --flavor        Verify a single flavor (default: all flavors)
  --keep          Leave scaffolds on disk for debugging instead of deleting
  --skip-audit    Skip 'pnpm audit' (use when blocked by an unfixable advisory)
  -h, --help      Show this help message
EOF
}

cleanup() {
  local dir
  if (( ${#WORKDIRS[@]} == 0 )); then
    return
  fi
  for dir in "${WORKDIRS[@]}"; do
    if [[ "$KEEP" == "true" ]]; then
      echo "Kept scaffold: $dir"
    else
      rm -rf "$dir"
    fi
  done
}

# The node flavor excludes integration tests from its coverage run; the react
# flavor has no such split. Read the answer from the scaffold instead of
# branching on flavor name, so a new flavor works without editing this.
resolve_test_script() {
  local dir="$1"
  if jq -e '.scripts["test:unit:coverage"]' "$dir/package.json" >/dev/null 2>&1; then
    echo "test:unit:coverage"
  else
    echo "test:coverage"
  fi
}

run_gate() {
  local dir="$1"
  local test_script
  test_script="$(resolve_test_script "$dir")"

  local step
  for step in "${GATE_STEPS[@]}"; do
    if [[ "$step" == "__TEST__" ]]; then
      step="$test_script"
    fi
    echo "  -> pnpm $step"
    ( cd "$dir" && pnpm "$step" )
  done

  if [[ "$SKIP_AUDIT" == "false" ]]; then
    echo "  -> pnpm audit"
    ( cd "$dir" && pnpm audit --audit-level moderate )
  fi
}

verify_flavor() {
  local flavor="$1"
  local base
  base="$(mktemp -d)"
  WORKDIRS+=("$base")

  echo "=== Verifying $flavor ==="

  # setup.sh refuses to write into an existing directory, so hand it a path
  # one level below the mktemp dir rather than the mktemp dir itself.
  echo "-- structural checks (private, no install)"
  "$SCRIPT_DIR/setup.sh" verify-private "$base/private" \
    --flavor "$flavor" --visibility private --no-install >/dev/null
  assert_visibility "$base/private" private
  assert_no_placeholders "$base/private"

  echo "-- full gate (public, with install)"
  "$SCRIPT_DIR/setup.sh" verify-public "$base/public" \
    --flavor "$flavor" --visibility public >/dev/null
  assert_visibility "$base/public" public
  assert_no_placeholders "$base/public"
  run_gate "$base/public"

  echo "=== $flavor OK ==="
}

main() {
  # Set here, not at file scope, so sourcing this file for tests is side-effect
  # free. `set -e` is a shell-wide option, so it covers every function below.
  set -euo pipefail

  while [[ $# -gt 0 ]]; do
    case "$1" in
      --flavor)
        SELECTED_FLAVORS=("$2")
        shift 2
        ;;
      --keep)
        KEEP=true
        shift
        ;;
      --skip-audit)
        SKIP_AUDIT=true
        shift
        ;;
      -h|--help)
        usage
        exit 0
        ;;
      *)
        echo "Error: Unknown option $1" >&2
        usage
        exit 1
        ;;
    esac
  done

  if (( ${#SELECTED_FLAVORS[@]} == 0 )); then
    SELECTED_FLAVORS=("${AVAILABLE_FLAVORS[@]}")
  fi

  local flavor
  for flavor in "${SELECTED_FLAVORS[@]}"; do
    if [[ ! -d "$SCRIPT_DIR/templates/$flavor" ]]; then
      echo "Error: Unknown flavor '$flavor'" >&2
      exit 1
    fi
  done

  trap cleanup EXIT

  for flavor in "${SELECTED_FLAVORS[@]}"; do
    verify_flavor "$flavor"
  done

  echo ""
  echo "All flavors verified."
}

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
  main "$@"
fi
