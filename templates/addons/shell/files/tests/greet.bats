#!/usr/bin/env bats

setup() {
  # shellcheck source=src/greet.sh
  source "$BATS_TEST_DIRNAME/../src/greet.sh"
}

@test "greets the world when no name is given" {
  run main
  [ "$status" -eq 0 ]
  [ "$output" = "Hello, world!" ]
}

@test "greets each name in turn" {
  run main Ada Grace
  [ "$status" -eq 0 ]
  [ "${lines[0]}" = "Hello, Ada!" ]
  [ "${lines[1]}" = "Hello, Grace!" ]
}

@test "runs as a command" {
  run "$BATS_TEST_DIRNAME/../src/greet.sh" Ada
  [ "$status" -eq 0 ]
  [ "$output" = "Hello, Ada!" ]
}
