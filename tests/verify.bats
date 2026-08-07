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

@test "resolve_test_script picks the node flavor's unit coverage script" {
  mkdir -p "$WORK"
  cat > "$WORK/package.json" <<'JSON'
{ "scripts": { "test:coverage": "vitest run --coverage",
               "test:unit:coverage": "vitest run --exclude x --coverage" } }
JSON
  run resolve_test_script "$WORK"
  [ "$status" -eq 0 ]
  [ "$output" = "test:unit:coverage" ]
}

@test "resolve_test_script falls back to plain coverage script" {
  mkdir -p "$WORK"
  cat > "$WORK/package.json" <<'JSON'
{ "scripts": { "test:coverage": "vitest run --coverage" } }
JSON
  run resolve_test_script "$WORK"
  [ "$status" -eq 0 ]
  [ "$output" = "test:coverage" ]
}

@test "--help exits zero" {
  run "$REPO_ROOT/verify.sh" --help
  [ "$status" -eq 0 ]
  [[ "$output" == *"--skip-audit"* ]]
}

@test "unknown flavor is rejected" {
  run "$REPO_ROOT/verify.sh" --flavor typescript-cobol
  [ "$status" -ne 0 ]
  [[ "$output" == *"Unknown flavor"* ]]
}
