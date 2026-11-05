#!/usr/bin/env bats

setup() {
  REPO_ROOT="$(cd "$BATS_TEST_DIRNAME/.." && pwd)"
  TEMPLATES_DIR="$BATS_TEST_DIRNAME/fixtures/templates"
  export TEMPLATES_DIR
  # shellcheck source=lib/compose.sh
  source "$REPO_ROOT/lib/compose.sh"
  WORK="$(mktemp -d)"
}

teardown() {
  rm -rf "$WORK"
}

@test "resolve_addons dedupes repeated names" {
  run resolve_addons alpha alpha beta
  [ "$status" -eq 0 ]
  [ "$output" = "$(printf 'alpha\nbeta')" ]
}

@test "resolve_addons rejects unknown addon" {
  run resolve_addons alpha nope
  [ "$status" -eq 1 ]
  [[ "$output" == *"Error: unknown addon 'nope'"* ]]
}

@test "resolve_addons rejects conflicting addons" {
  run resolve_addons alpha gamma
  [ "$status" -eq 1 ]
  [[ "$output" == *"Error: addons 'alpha' and 'gamma' can't be combined"* ]]
}

@test "resolve_addons rejects a conflict declared only by the later addon" {
  run resolve_addons gamma alpha
  [ "$status" -eq 1 ]
  [[ "$output" == *"'gamma'"* && "$output" == *"'alpha'"* ]]
}

@test "resolve_common dedupes common dirs shared by two addons" {
  run resolve_common alpha beta delta
  [ "$status" -eq 0 ]
  [ "$output" = "shared" ]
}

@test "merge_renovate appends addon packageRules after base rules" {
  merge_renovate "$WORK/renovate.json" alpha delta
  run jq -r '[.packageRules[].description] | join(",")' "$WORK/renovate.json"
  [ "$output" = "base rule,alpha rule,delta rule" ]
  run jq -r '[.customManagers[].description] | join(",")' "$WORK/renovate.json"
  [ "$output" = "base manager,alpha manager" ]
  run jq -r '.extends[0]' "$WORK/renovate.json"
  [ "$output" = "config:recommended" ]
}

@test "build_gitignore puts each section under a header" {
  build_gitignore "$WORK/.gitignore" alpha beta
  run cat "$WORK/.gitignore"
  [[ "$output" == *"# base"*".env"*"# alpha"*"__pycache__/"* ]]
  run grep -c '^# beta$' "$WORK/.gitignore"
  [ "$output" = "0" ]
}

@test "build_codecov writes nothing without coverage addons" {
  build_codecov "$WORK/codecov.yml" beta
  [ ! -e "$WORK/codecov.yml" ]
}

@test "build_codecov sums uploads into after_n_builds" {
  build_codecov "$WORK/codecov.yml" alpha delta
  run grep -c 'after_n_builds: 3' "$WORK/codecov.yml"
  [ "$output" = "2" ]
  run grep -c 'component_id:' "$WORK/codecov.yml"
  [ "$output" = "2" ]
  grep -q 'target: 90%' "$WORK/codecov.yml"
  grep -q 'project: off' "$WORK/codecov.yml"
  grep -q 'carryforward: true' "$WORK/codecov.yml"
}

@test "codeql_languages always includes actions and dedupes" {
  run codeql_languages public alpha beta delta
  [ "$output" = "[actions, python, javascript-typescript]" ]
  run codeql_languages public
  [ "$output" = "[actions]" ]
}

@test "codeql_languages is empty for private" {
  run codeql_languages private alpha
  [ "$status" -eq 0 ]
  [ -z "$output" ]
}

@test "required_checks base only has no codecov/patch" {
  run required_checks public
  [ "$(jq -r '[.[].context] | join(",")' <<<"$output")" = "gitleaks,zizmor,analyze (actions)" ]
  [ "$(jq -r 'map(.integration_id) | unique | join(",")' <<<"$output")" = "15368" ]
}

@test "required_checks includes codecov/patch with 254 when an addon has coverage" {
  run required_checks public alpha beta
  [ "$(jq -r '[.[].context] | join(",")' <<<"$output")" = "gitleaks,zizmor,alpha-lint,alpha-test,beta-lint,analyze (actions),analyze (python),codecov/patch" ]
  [ "$(jq -r '.[] | select(.context == "codecov/patch") | .integration_id' <<<"$output")" = "254" ]
}

@test "required_checks lists each check once for repeated addons" {
  run required_checks public alpha alpha
  [ "$(jq '[.[].context] | length' <<<"$output")" = "$(jq '[.[].context] | unique | length' <<<"$output")" ]
}

@test "required_checks leaves out CodeQL for private" {
  run required_checks private alpha
  [ "$(jq '[.[].context | select(startswith("analyze"))] | length' <<<"$output")" = "0" ]
}

@test "write_manifest records visibility and codeScanning false for private" {
  write_manifest "$WORK/repo-standards.json" private alpha
  run jq -c '{addons, visibility, codeScanning, coverage, repoSettings}' "$WORK/repo-standards.json"
  [ "$output" = '{"addons":["alpha"],"visibility":"private","codeScanning":false,"coverage":true,"repoSettings":{}}' ]
  run jq '.requiredChecks | length' "$WORK/repo-standards.json"
  [ "$output" = "5" ]
}
