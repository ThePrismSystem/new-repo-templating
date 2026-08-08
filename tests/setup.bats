#!/usr/bin/env bats

setup() {
  REPO_ROOT="$(cd "$BATS_TEST_DIRNAME/.." && pwd)"
  WORK="$(mktemp -d)"
}

teardown() {
  rm -rf "$WORK"
}

@test "--no-install skips dependency installation" {
  run "$REPO_ROOT/setup.sh" demo "$WORK/proj" --flavor typescript-node --no-install
  [ "$status" -eq 0 ]
  [ ! -d "$WORK/proj/node_modules" ]
  [ -d "$WORK/proj/.git" ]
}

@test "--no-install still substitutes placeholders" {
  run "$REPO_ROOT/setup.sh" demo "$WORK/proj" --flavor typescript-node --no-install
  [ "$status" -eq 0 ]
  run grep -c '{{PROJECT_NAME}}' "$WORK/proj/package.json"
  [ "$status" -ne 0 ]
  run grep -q '"name": "demo"' "$WORK/proj/package.json"
  [ "$status" -eq 0 ]
}

@test "public visibility includes CodeQL and Gitleaks workflows" {
  run "$REPO_ROOT/setup.sh" demo "$WORK/proj" --flavor typescript-node --visibility public --no-install
  [ "$status" -eq 0 ]
  [ -f "$WORK/proj/.github/workflows/codeql.yml" ]
  [ -f "$WORK/proj/.github/workflows/gitleaks.yml" ]
}

@test "private visibility omits CodeQL and Gitleaks workflows" {
  run "$REPO_ROOT/setup.sh" demo "$WORK/proj" --flavor typescript-node --visibility private --no-install
  [ "$status" -eq 0 ]
  [ ! -f "$WORK/proj/.github/workflows/codeql.yml" ]
  [ ! -f "$WORK/proj/.github/workflows/gitleaks.yml" ]
  [ -f "$WORK/proj/.github/workflows/ci.yml" ]
}

@test "succeeds when USER is unset and gh is unauthenticated" {
  # Both halves matter. Unsetting USER alone proves nothing on a machine where
  # 'gh api user' succeeds, because the fallback branch never runs. Pointing
  # GH_CONFIG_DIR at an empty directory and clearing GH_TOKEN forces gh to fail,
  # which is what drives execution into the "${USER:-unknown}" path.
  mkdir -p "$WORK/empty-gh"
  run env -u USER GH_TOKEN= GH_CONFIG_DIR="$WORK/empty-gh" \
    "$REPO_ROOT/setup.sh" demo "$WORK/proj" --flavor typescript-node --no-install
  [ "$status" -eq 0 ]
  run grep -q 'unknown' "$WORK/proj/.github/CODEOWNERS"
  [ "$status" -eq 0 ]
}
