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
