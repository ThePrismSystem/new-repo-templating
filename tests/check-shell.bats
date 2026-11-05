#!/usr/bin/env bats

setup() {
  REPO_ROOT="$(cd "$BATS_TEST_DIRNAME/.." && pwd)"
  WORK="$(mktemp -d)"
  mkdir -p "$WORK/tests"
  # Written with printf: bats would read an @test line in a heredoc as a test
  # of this file.
  local at=@
  printf "%s\n" "#!/usr/bin/env bats" "" "${at}test \"quick\" {" "  true" "}" "" \
    "# bats test_tags=slow" "${at}test \"slow\" {" "  false" "}" >"$WORK/tests/sample.bats"
}

teardown() {
  rm -rf "$WORK"
}

@test "test runs every bats test by default" {
  cd "$WORK" || return 1
  # This suite itself runs with BATS_FILTER_TAGS set in CI.
  unset BATS_FILTER_TAGS
  run "$REPO_ROOT/templates/addons/shell/files/scripts/check-shell.sh" test
  [ "$status" -ne 0 ]
  [[ "$output" == *"not ok 2 slow"* ]]
}

@test "test passes BATS_FILTER_TAGS to bats" {
  cd "$WORK" || return 1
  BATS_FILTER_TAGS='!slow' run "$REPO_ROOT/templates/addons/shell/files/scripts/check-shell.sh" test
  [ "$status" -eq 0 ]
  [[ "$output" == *"ok 1 quick"* && "$output" != *"slow"* ]]
}
