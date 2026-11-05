#!/usr/bin/env bats

setup() {
  REPO_ROOT="$(cd "$BATS_TEST_DIRNAME/.." && pwd)"
  CHECK="$REPO_ROOT/templates/base/files/scripts/check-base.sh"
  WORK="$(mktemp -d)"
  git -C "$WORK" init -q -b main
  git -C "$WORK" config user.name test
  git -C "$WORK" config user.email test@example.invalid
  git -C "$WORK" config commit.gpgsign false
  git -C "$WORK" commit -q --allow-empty -m "chore: start"
  BASE_SHA="$(git -C "$WORK" rev-parse HEAD)"
  export BASE_SHA
}

teardown() {
  rm -rf "$WORK"
}

commit() {
  git -C "$WORK" commit -q --allow-empty -m "$1"
}

run_commits() {
  HEAD_SHA="$(git -C "$WORK" rev-parse HEAD)"
  export HEAD_SHA
  cd "$WORK" || return 1
  run env PR_TITLE="$1" "$CHECK" commits
}

@test "commits accepts a conventional title" {
  commit "feat(api): add a thing"
  run_commits "feat(api): add a thing"
  [ "$status" -eq 0 ]
}

@test "commits rejects a title without a type" {
  commit "fix: a thing"
  run_commits "Add a thing"
  [ "$status" -eq 1 ]
  [[ "$output" == *"Add a thing"* ]]
}

@test "commits rejects a commit subject without a type" {
  commit "Update stuff"
  run_commits "fix: update stuff"
  [ "$status" -eq 1 ]
  [[ "$output" == *"Update stuff"* ]]
}

@test "commits ignores merge commits" {
  git -C "$WORK" checkout -q -b topic
  commit "fix: on topic"
  git -C "$WORK" checkout -q main
  commit "chore: on main"
  git -C "$WORK" checkout -q topic
  git -C "$WORK" merge -q --no-ff --no-edit main
  run_commits "fix: on topic"
  [ "$status" -eq 0 ]
}

@test "commits rejects a header over 100 chars" {
  commit "fix: short"
  run_commits "fix: $(printf 'x%.0s' {1..100})"
  [ "$status" -eq 1 ]
  [[ "$output" == *"100"* ]]
}

@test "commits needs PR_TITLE, BASE_SHA and HEAD_SHA" {
  cd "$WORK" || return 1
  run env -u PR_TITLE "$CHECK" commits
  [ "$status" -ne 0 ]
}

@test "unknown step exits non-zero with usage" {
  run "$CHECK" nope
  [ "$status" -eq 2 ]
  [[ "$output" == *"Usage"* ]]
}
