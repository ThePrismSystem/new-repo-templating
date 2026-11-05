#!/usr/bin/env bash
# `set -euo pipefail` lives in main() rather than at the top level on purpose:
# tests/verify.bats sources this file, and setting shell options at load time
# would leak errexit and nounset into the bats test shell.

PUBLIC_ONLY_WORKFLOWS=(".github/workflows/codeql.yml" ".github/workflows/scorecard.yml")

# Fails if setup.sh left any {{PLACEHOLDER}} unsubstituted in the scaffold.
# grep exits 0 when it finds a match, which is the failure case here.
assert_no_placeholders() {
  local dir="$1"
  local hits
  if hits="$(grep -rIn '{{[A-Z_]\+}}' "$dir" \
    --exclude-dir=node_modules --exclude-dir=.git --exclude-dir=.venv 2>/dev/null)"; then
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

AVAILABLE_ADDONS=()
for addon_path in "$SCRIPT_DIR"/templates/addons/*/; do
  addon_path="${addon_path%/}"
  AVAILABLE_ADDONS+=("${addon_path##*/}")
done
unset addon_path

KEEP=false
SKIP_AUDIT=false
SELECTED_ADDONS=()
COMBO_ADDONS=()
WORKDIRS=()

usage() {
  cat <<EOF
Usage: $0 [--addon <name> | --combo <name,name,...>] [--keep] [--skip-audit]

Scaffolds each addon into a temporary directory and runs the same gate the
generated project's own CI runs.

Options:
  --addon         Verify a single addon (default: all addons)
                  Available: ${AVAILABLE_ADDONS[*]}
  --combo         Verify one scaffold with these addons stacked together
  --keep          Leave scaffolds on disk for debugging instead of deleting
  --skip-audit    Skip dependency audits (use when blocked by an unfixable advisory)
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

# Runs the check script of every addon the scaffold was built with, the same
# script each addon's CI jobs call one step at a time.
run_gate() {
  local dir="$1"
  local addon check
  while IFS= read -r addon; do
    check="$(jq -r '.check // empty' "$SCRIPT_DIR/templates/addons/$addon/addon.json")"
    if [[ -z "$check" ]]; then
      echo "FAIL: addon '$addon' has no check script in addon.json" >&2
      return 1
    fi
    echo "  -> $check all"
    (
      cd "$dir"
      if [[ "$SKIP_AUDIT" == "true" ]]; then
        export SKIP_AUDIT=1
      else
        unset SKIP_AUDIT
      fi
      "$check" all
    )
  done < <(jq -r '.addons[]' "$dir/.github/repo-standards.json")
}

# gitleaks reads history, so the scaffold gets one commit first. Hooks are
# skipped: the gate below runs everything they would.
run_base_gate() {
  local dir="$1"
  echo "  -> scripts/check-base.sh all"
  (
    cd "$dir"
    git add -A
    git -c user.name=verify -c user.email=verify@example.invalid \
      commit -q --no-verify --no-gpg-sign -m "chore: initial scaffold"
    scripts/check-base.sh all
  )
}

# Verifies one scaffold built from the given addons, named by <label>.
verify_scaffold() {
  local label="$1"
  shift
  local base addon args=()
  base="$(mktemp -d)"
  WORKDIRS+=("$base")
  for addon in "$@"; do
    args+=(--addon "$addon")
  done

  echo "=== Verifying $label ==="

  # setup.sh refuses to write into an existing directory, so hand it a path
  # one level below the mktemp dir rather than the mktemp dir itself.
  echo "-- structural checks (private, no install)"
  "$SCRIPT_DIR/setup.sh" verify-private "$base/private" \
    "${args[@]}" --visibility private --no-install >/dev/null
  assert_visibility "$base/private" private
  assert_no_placeholders "$base/private"

  echo "-- full gate (public, with install)"
  "$SCRIPT_DIR/setup.sh" verify-public "$base/public" \
    "${args[@]}" --visibility public >/dev/null
  assert_visibility "$base/public" public
  assert_no_placeholders "$base/public"
  run_gate "$base/public"
  run_base_gate "$base/public"

  echo "=== $label OK ==="
}

main() {
  # Set here, not at file scope, so sourcing this file for tests is side-effect
  # free. `set -e` is a shell-wide option, so it covers every function below.
  set -euo pipefail

  while [[ $# -gt 0 ]]; do
    case "$1" in
      --addon)
        SELECTED_ADDONS=("$2")
        shift 2
        ;;
      --combo)
        IFS=, read -r -a COMBO_ADDONS <<<"$2"
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

  if (( ${#SELECTED_ADDONS[@]} == 0 && ${#COMBO_ADDONS[@]} == 0 )); then
    SELECTED_ADDONS=("${AVAILABLE_ADDONS[@]}")
  fi

  local addon
  for addon in "${SELECTED_ADDONS[@]}" "${COMBO_ADDONS[@]}"; do
    if [[ ! -f "$SCRIPT_DIR/templates/addons/$addon/addon.json" ]]; then
      echo "Error: Unknown addon '$addon'" >&2
      exit 1
    fi
  done

  trap cleanup EXIT

  for addon in "${SELECTED_ADDONS[@]}"; do
    verify_scaffold "$addon" "$addon"
  done
  if (( ${#COMBO_ADDONS[@]} > 0 )); then
    verify_scaffold "combo (${COMBO_ADDONS[*]})" "${COMBO_ADDONS[@]}"
  fi

  echo ""
  echo "All addons verified."
}

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
  main "$@"
fi
