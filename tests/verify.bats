#!/usr/bin/env bats

setup() {
  REPO_ROOT="$(cd "$BATS_TEST_DIRNAME/.." && pwd)"
  # shellcheck source=/dev/null
  source "$REPO_ROOT/verify.sh"
  WORK="$(mktemp -d)"
}

teardown() {
  rm -rf "$WORK"
}

@test "assert_no_placeholders passes on a clean directory" {
  mkdir -p "$WORK/src"
  echo "const name = 'demo';" > "$WORK/src/index.ts"
  run assert_no_placeholders "$WORK"
  [ "$status" -eq 0 ]
}

@test "assert_no_placeholders fails on an unsubstituted placeholder" {
  mkdir -p "$WORK/src"
  echo "const name = '{{PROJECT_NAME}}';" > "$WORK/src/index.ts"
  run assert_no_placeholders "$WORK"
  [ "$status" -eq 1 ]
  [[ "$output" == *"PROJECT_NAME"* ]]
}

@test "assert_no_placeholders ignores node_modules and .git" {
  mkdir -p "$WORK/node_modules/pkg" "$WORK/.git"
  echo "{{SOMETHING}}" > "$WORK/node_modules/pkg/index.js"
  echo "{{ELSE}}" > "$WORK/.git/description"
  run assert_no_placeholders "$WORK"
  [ "$status" -eq 0 ]
}

@test "assert_visibility passes when public scaffold has both workflows" {
  mkdir -p "$WORK/.github/workflows"
  touch "$WORK/.github/workflows/codeql.yml" "$WORK/.github/workflows/gitleaks.yml"
  run assert_visibility "$WORK" public
  [ "$status" -eq 0 ]
}

@test "assert_visibility fails when public scaffold is missing a workflow" {
  mkdir -p "$WORK/.github/workflows"
  touch "$WORK/.github/workflows/codeql.yml"
  run assert_visibility "$WORK" public
  [ "$status" -eq 1 ]
  [[ "$output" == *"gitleaks.yml"* ]]
}

@test "assert_visibility passes when private scaffold has neither workflow" {
  mkdir -p "$WORK/.github/workflows"
  touch "$WORK/.github/workflows/ci.yml"
  run assert_visibility "$WORK" private
  [ "$status" -eq 0 ]
}

@test "assert_visibility fails when private scaffold leaks a public workflow" {
  mkdir -p "$WORK/.github/workflows"
  touch "$WORK/.github/workflows/codeql.yml"
  run assert_visibility "$WORK" private
  [ "$status" -eq 1 ]
  [[ "$output" == *"codeql.yml"* ]]
}
