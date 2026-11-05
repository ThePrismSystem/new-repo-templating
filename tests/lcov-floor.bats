#!/usr/bin/env bats

setup() {
  REPO_ROOT="$(cd "$BATS_TEST_DIRNAME/.." && pwd)"
  FLOOR="$REPO_ROOT/templates/addons/lua/files/scripts/lcov-floor.sh"
  WORK="$(mktemp -d)"
}

teardown() {
  rm -rf "$WORK"
}

report() {
  printf '%s\n' "$@" >"$WORK/lcov.info"
}

@test "passes when the summed line coverage meets the floor" {
  report "SF:a.lua" "LH:8" "LF:10" "end_of_record" "SF:b.lua" "LH:9" "LF:10" "end_of_record"
  run "$FLOOR" "$WORK/lcov.info" 80
  [ "$status" -eq 0 ]
  [[ "$output" == *"85.00%"* ]]
}

@test "fails under the floor and prints the total" {
  report "SF:a.lua" "LH:8" "LF:10" "end_of_record" "SF:b.lua" "LH:0" "LF:10" "end_of_record"
  run "$FLOOR" "$WORK/lcov.info" 80
  [ "$status" -eq 1 ]
  [[ "$output" == *"40.00%"* && "$output" == *"80%"* ]]
}

@test "coverage exactly at the floor passes" {
  report "SF:a.lua" "LH:4" "LF:5" "end_of_record"
  run "$FLOOR" "$WORK/lcov.info" 80
  [ "$status" -eq 0 ]
}

@test "only LH and LF records count" {
  report "SF:a.lua" "BRH:0" "BRF:50" "FNH:0" "FNF:9" "LH:9" "LF:10" "end_of_record"
  run "$FLOOR" "$WORK/lcov.info" 80
  [ "$status" -eq 0 ]
  [[ "$output" == *"90.00%"* ]]
}

@test "fails when the report has no lines to count" {
  report "SF:a.lua" "end_of_record"
  run "$FLOOR" "$WORK/lcov.info" 80
  [ "$status" -eq 1 ]
  [[ "$output" == *"No lines"* ]]
}

@test "fails when the report can't be read" {
  run "$FLOOR" "$WORK/missing.info" 80
  [ "$status" -eq 2 ]
  [[ "$output" == *"missing.info"* ]]
}

@test "prints usage without two arguments" {
  run "$FLOOR" "$WORK/lcov.info"
  [ "$status" -eq 2 ]
  [[ "$output" == *"Usage"* ]]
}
