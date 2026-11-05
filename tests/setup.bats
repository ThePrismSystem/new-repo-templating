#!/usr/bin/env bats

setup() {
  REPO_ROOT="$(cd "$BATS_TEST_DIRNAME/.." && pwd)"
  WORK="$(mktemp -d)"
}

teardown() {
  rm -rf "$WORK"
}

@test "--no-install skips dependency installation" {
  run "$REPO_ROOT/setup.sh" demo "$WORK/proj" --addon typescript-node --no-install
  [ "$status" -eq 0 ]
  [ ! -d "$WORK/proj/node_modules" ]
  [ -d "$WORK/proj/.git" ]
}

@test "--no-install still substitutes placeholders" {
  run "$REPO_ROOT/setup.sh" demo "$WORK/proj" --addon typescript-node --no-install
  [ "$status" -eq 0 ]
  run grep -c '{{PROJECT_NAME}}' "$WORK/proj/package.json"
  [ "$status" -ne 0 ]
  run grep -q '"name": "demo"' "$WORK/proj/package.json"
  [ "$status" -eq 0 ]
}

@test "public visibility includes CodeQL and Scorecard workflows" {
  run "$REPO_ROOT/setup.sh" demo "$WORK/proj" --addon typescript-node --visibility public --no-install
  [ "$status" -eq 0 ]
  [ -f "$WORK/proj/.github/workflows/codeql.yml" ]
  [ -f "$WORK/proj/.github/workflows/scorecard.yml" ]
  [ -f "$WORK/proj/.github/workflows/lint.yml" ]
}

@test "private visibility omits CodeQL and Scorecard but keeps lint" {
  run "$REPO_ROOT/setup.sh" demo "$WORK/proj" --addon typescript-node --visibility private --no-install
  [ "$status" -eq 0 ]
  [ ! -f "$WORK/proj/.github/workflows/codeql.yml" ]
  [ ! -f "$WORK/proj/.github/workflows/scorecard.yml" ]
  [ -f "$WORK/proj/.github/workflows/lint.yml" ]
}

@test "public scaffold uploads SARIF, private scaffold doesn't" {
  run "$REPO_ROOT/setup.sh" pub "$WORK/pub" --visibility public --no-install
  [ "$status" -eq 0 ]
  run grep -c 'upload-sarif' "$WORK/pub/.github/workflows/lint.yml"
  [ "$output" -ge 2 ]
  run "$REPO_ROOT/setup.sh" priv "$WORK/priv" --visibility private --no-install
  [ "$status" -eq 0 ]
  run grep -rl 'upload-sarif\|security-events' "$WORK/priv/.github/workflows"
  [ -z "$output" ]
  run grep -rn '# >>> public\|# <<< public' "$WORK/priv" "$WORK/pub"
  [ -z "$output" ]
}

@test "every action in a scaffold is pinned to a 40-char SHA" {
  run "$REPO_ROOT/setup.sh" demo "$WORK/proj" --addon typescript-node --no-install
  [ "$status" -eq 0 ]
  run bash -c "grep -rhE '^\s*(- )?uses: ' '$WORK/proj/.github/workflows' | grep -vE 'uses: [^@]+@[0-9a-f]{40} # v[0-9]'"
  [ -z "$output" ]
}

@test "every workflow in a scaffold starts with empty permissions" {
  run "$REPO_ROOT/setup.sh" demo "$WORK/proj" --addon typescript-node --no-install
  [ "$status" -eq 0 ]
  local wf
  for wf in "$WORK"/proj/.github/workflows/*.yml; do
    grep -q '^permissions: {}$' "$wf"
  done
}

@test "succeeds when USER is unset and gh is unauthenticated" {
  # Both halves matter. Unsetting USER alone proves nothing on a machine where
  # 'gh api user' succeeds, because the fallback branch never runs. Pointing
  # GH_CONFIG_DIR at an empty directory and clearing GH_TOKEN forces gh to fail,
  # which is what drives execution into the "${USER:-unknown}" path.
  mkdir -p "$WORK/empty-gh"
  run env -u USER GH_TOKEN= GH_CONFIG_DIR="$WORK/empty-gh" \
    "$REPO_ROOT/setup.sh" demo "$WORK/proj" --addon typescript-node --no-install
  [ "$status" -eq 0 ]
  run grep -q 'unknown' "$WORK/proj/.github/CODEOWNERS"
  [ "$status" -eq 0 ]
}

@test "rejects a project name with uppercase or spaces" {
  run "$REPO_ROOT/setup.sh" "My App" "$WORK/proj" --no-install
  [ "$status" -eq 1 ]
  [[ "$output" == *"lowercase letters, digits and hyphens"* ]]
  [ ! -e "$WORK/proj" ]
  run "$REPO_ROOT/setup.sh" "Demo" "$WORK/proj" --no-install
  [ "$status" -eq 1 ]
  [ ! -e "$WORK/proj" ]
}

@test "rejects a project name with characters sed would misread" {
  run "$REPO_ROOT/setup.sh" "a/b&c" "$WORK/proj" --no-install
  [ "$status" -eq 1 ]
  [ ! -e "$WORK/proj" ]
}

@test "unknown addon exits 1 before copying" {
  run "$REPO_ROOT/setup.sh" demo "$WORK/proj" --addon cobol --no-install
  [ "$status" -eq 1 ]
  [[ "$output" == *"unknown addon 'cobol'"* ]]
  [ ! -e "$WORK/proj" ]
}

@test "conflicting addons exit 1 before copying" {
  run "$REPO_ROOT/setup.sh" demo "$WORK/proj" --addon typescript-node --addon typescript-react --no-install
  [ "$status" -eq 1 ]
  [[ "$output" == *"can't be combined"* ]]
  [ ! -e "$WORK/proj" ]
}

@test "base only scaffold has no codecov.yml and no package.json" {
  run "$REPO_ROOT/setup.sh" demo "$WORK/proj" --no-install
  [ "$status" -eq 0 ]
  [ -f "$WORK/proj/.gitignore" ]
  [ -f "$WORK/proj/renovate.json" ]
  [ ! -e "$WORK/proj/codecov.yml" ]
  [ ! -e "$WORK/proj/package.json" ]
  run grep -F 'language: [actions]' "$WORK/proj/.github/workflows/codeql.yml"
  [ "$status" -eq 0 ]
  run jq -r '[.requiredChecks[].context] | index("codecov/patch")' "$WORK/proj/.github/repo-standards.json"
  [ "$output" = "null" ]
}

@test "manifest lists the addons and required checks" {
  run "$REPO_ROOT/setup.sh" demo "$WORK/proj" --addon typescript-node --no-install
  [ "$status" -eq 0 ]
  run jq -c '.addons' "$WORK/proj/.github/repo-standards.json"
  [ "$output" = '["typescript-node"]' ]
  run jq -r '[.requiredChecks[].context] | (index("codecov/patch") != null) and (index("analyze (javascript-typescript)") != null)' \
    "$WORK/proj/.github/repo-standards.json"
  [ "$output" = "true" ]
}

@test "typescript scaffold gets the common node files and a merged gitignore" {
  run "$REPO_ROOT/setup.sh" demo "$WORK/proj" --addon typescript-node --no-install
  [ "$status" -eq 0 ]
  [ -f "$WORK/proj/pnpm-workspace.yaml" ]
  [ -f "$WORK/proj/commitlint.config.js" ]
  run grep -c '^# typescript-node$' "$WORK/proj/.gitignore"
  [ "$output" = "1" ]
  run grep -q '^node_modules/$' "$WORK/proj/.gitignore"
  [ "$status" -eq 0 ]
}

@test "private scaffold has no codeql.yml and a manifest without code scanning" {
  run "$REPO_ROOT/setup.sh" demo "$WORK/proj" --visibility private --no-install
  [ "$status" -eq 0 ]
  [ ! -e "$WORK/proj/.github/workflows/codeql.yml" ]
  [ ! -e "$WORK/proj/.github/codeql" ]
  run jq -r '.codeScanning' "$WORK/proj/.github/repo-standards.json"
  [ "$output" = "false" ]
}

@test "manifest requires every job in the base lint workflow" {
  run "$REPO_ROOT/setup.sh" demo "$WORK/proj" --no-install
  [ "$status" -eq 0 ]
  local job
  # Job ids sit at two spaces under `jobs:`, and each job's name is its id.
  local jobs
  jobs="$(awk '/^jobs:/ { in_jobs = 1; next } in_jobs && /^  [a-z-]+:$/ { gsub(/[ :]/, ""); print }' \
    "$WORK/proj/.github/workflows/lint.yml")"
  [ "$(wc -l <<<"$jobs")" -eq 6 ]
  for job in $jobs; do
    jq -e --arg job "$job" '[.requiredChecks[].context] | index($job) != null' "$WORK/proj/.github/repo-standards.json" >/dev/null
  done
}

@test "ends by printing the repo create and apply-settings commands" {
  run env GH_TOKEN= GH_CONFIG_DIR="$WORK" USER=someone \
    "$REPO_ROOT/setup.sh" demo "$WORK/proj" --visibility private --no-install
  [ "$status" -eq 0 ]
  [[ "$output" == *"gh repo create someone/demo --private --source . --push"* ]]
  [[ "$output" == *"apply-settings.sh someone/demo"* ]]
}

@test "every release download in a scaffold retries with a fixed delay" {
  run "$REPO_ROOT/setup.sh" demo "$WORK/proj" --no-install
  [ "$status" -eq 0 ]
  local downloads
  downloads="$(grep -rh 'curl ' "$WORK/proj/.github/workflows")"
  [ -n "$downloads" ]
  run grep -v -- '--retry 5 --retry-delay 10 --retry-all-errors' <<<"$downloads"
  [ "$status" -eq 1 ]
}
