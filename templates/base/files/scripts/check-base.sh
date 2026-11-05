#!/usr/bin/env bash
# The checks every repo built from these templates shares. Each CI job in
# .github/workflows/lint.yml runs one step; run `all` locally before pushing.
# The tools must be on PATH: CI installs the versions pinned in the workflow.

# The Conventional Commits types commitlint's conventional config accepts.
CONVENTIONAL_RE='^(build|chore|ci|docs|feat|fix|perf|refactor|revert|style|test)(\([a-z0-9._/-]+\))?!?: .+$'
# commitlint's conventional config allows headers up to 100 characters.
MAX_HEADER=100

usage() {
  cat <<EOF
Usage: $0 <step>

Steps:
  gitleaks       Scan the whole git history for secrets
  zizmor         Audit the GitHub Actions workflows
  actionlint     Lint the GitHub Actions workflows
  typos          Spell check
  markdownlint   Lint Markdown
  commits        Check PR_TITLE and every commit from BASE_SHA to HEAD_SHA
                 against the Conventional Commits format
  all            Every step above (commits only when PR_TITLE is set)

With SARIF_DIR set, gitleaks and zizmor also write <tool>.sarif there.
EOF
}

check_header() {
  local header="$1" what="$2"
  if ((${#header} > MAX_HEADER)); then
    echo "$what is ${#header} characters, over the $MAX_HEADER limit: $header" >&2
    return 1
  fi
  if [[ ! "$header" =~ $CONVENTIONAL_RE ]]; then
    echo "$what isn't a Conventional Commit (type(scope): description): $header" >&2
    return 1
  fi
}

step_commits() {
  : "${PR_TITLE:?PR_TITLE must be set}" "${BASE_SHA:?BASE_SHA must be set}" "${HEAD_SHA:?HEAD_SHA must be set}"
  local failed=0 subject
  check_header "$PR_TITLE" "PR title" || failed=1
  while IFS= read -r subject; do
    check_header "$subject" "Commit subject" || failed=1
  done < <(git log --no-merges --format=%s "$BASE_SHA..$HEAD_SHA")
  return "$failed"
}

step_gitleaks() {
  if [[ -n "${SARIF_DIR:-}" ]]; then
    mkdir -p "$SARIF_DIR"
    gitleaks git --no-banner --redact --report-format sarif --report-path "$SARIF_DIR/gitleaks.sarif"
  else
    gitleaks git --no-banner --redact
  fi
}

step_zizmor() {
  local status=0
  zizmor . || status=$?
  if [[ -n "${SARIF_DIR:-}" ]]; then
    mkdir -p "$SARIF_DIR"
    zizmor --format sarif . >"$SARIF_DIR/zizmor.sarif" || true
  fi
  return "$status"
}

step_actionlint() {
  actionlint
}

step_typos() {
  typos
}

step_markdownlint() {
  markdownlint-cli2 "**/*.md"
}

main() {
  set -euo pipefail
  local step="${1:-}"
  case "$step" in
    gitleaks | zizmor | actionlint | typos | markdownlint | commits)
      "step_$step"
      ;;
    all)
      local name
      for name in gitleaks zizmor actionlint typos markdownlint; do
        echo "-- $name"
        "step_$name"
      done
      if [[ -n "${PR_TITLE:-}" ]]; then
        echo "-- commits"
        step_commits
      fi
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
