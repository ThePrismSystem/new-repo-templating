#!/usr/bin/env bash
# Applies the standard repo settings, security settings and rulesets to a
# GitHub repo. Safe to run again: each change is compared with the current
# state first and skipped when nothing differs.

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TEMPLATES_DIR="$SCRIPT_DIR/templates"
# shellcheck source=lib/compose.sh
source "$SCRIPT_DIR/lib/compose.sh"
# shellcheck source=lib/settings.sh
source "$SCRIPT_DIR/lib/settings.sh"

usage() {
  cat <<EOF
Usage: $0 <owner/repo> [--manifest <path>] [--addon <name>]... [--visibility public|private] [--dry-run]

Reads the repo's .github/repo-standards.json (or the file given with
--manifest) and applies merge-commit-only settings, secret scanning, Dependabot
alerts, private vulnerability reporting, and the 'main' and 'release tags'
rulesets with the manifest's required checks.

Options:
  --manifest      Use this manifest instead of the one in the repo
  --addon         Work the manifest out from these addons instead, for a repo
                  that has none. Repeat for more than one.
  --visibility    With --addon: public (default) or private
  --dry-run       Print each change and make none of them
  -h, --help      Show this help message

With CODECOV_TOKEN set, it is stored as a repo secret when an addon uploads
coverage.
EOF
}

main() {
  set -euo pipefail
  local repo="" manifest="" visibility="public"
  local addons=()
  DRY_RUN=false

  while [[ $# -gt 0 ]]; do
    case "$1" in
      --manifest)
        manifest="$2"
        shift 2
        ;;
      --addon)
        addons+=("$2")
        shift 2
        ;;
      --visibility)
        visibility="$2"
        if [[ "$visibility" != "public" && "$visibility" != "private" ]]; then
          fail "--visibility must be 'public' or 'private'"
        fi
        shift 2
        ;;
      --dry-run)
        DRY_RUN=true
        shift
        ;;
      -h | --help)
        usage
        exit 0
        ;;
      -*)
        echo "Error: Unknown option $1" >&2
        usage >&2
        exit 1
        ;;
      *)
        repo="$1"
        shift
        ;;
    esac
  done

  if [[ ! "$repo" =~ ^[A-Za-z0-9_.-]+/[A-Za-z0-9_.-]+$ ]]; then
    usage >&2
    exit 1
  fi

  if ! gh auth status >/dev/null 2>&1; then
    fail "gh isn't logged in. Run gh auth login first."
  fi

  local work
  work="$(mktemp -d)"
  # shellcheck disable=SC2064 # expand $work now, while it's in scope
  trap "rm -rf '$work'" EXIT

  if [[ -z "$manifest" ]]; then
    manifest="$work/repo-standards.json"
    if ((${#addons[@]} > 0)); then
      local resolved
      resolved="$(resolve_addons "${addons[@]}")" || exit 1
      mapfile -t addons <<<"$resolved"
      write_manifest "$manifest" "$visibility" "${addons[@]}"
    else
      local content
      content="$(gh api "repos/$repo/contents/.github/repo-standards.json" 2>/dev/null)" ||
        fail "$repo has no .github/repo-standards.json. Pass --manifest <path>, or --addon <name> for each addon the repo uses."
      jq -r '.content' <<<"$content" | base64 -d >"$manifest"
    fi
  fi

  apply_settings "$repo" "$manifest"

  echo ""
  if [[ "$DRY_RUN" == "true" ]]; then
    echo "Dry run: nothing was changed."
  else
    echo "Settings applied to $repo."
  fi
  echo ""
  echo "Two steps this script can't do:"
  echo "  - Install the Renovate GitHub app on $repo: https://github.com/apps/renovate"
  echo "  - Install the Codecov GitHub app on $repo (https://github.com/apps/codecov), then"
  echo "    set CODECOV_TOKEN and run this again, or add the secret by hand"
}

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
  main "$@"
fi
