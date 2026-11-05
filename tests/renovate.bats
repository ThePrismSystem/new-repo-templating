#!/usr/bin/env bats

setup() {
  REPO_ROOT="$(cd "$BATS_TEST_DIRNAME/.." && pwd)"
}

@test "this repo's renovate.json reads every renovate comment in its workflows and the templates" {
  local files=()
  mapfile -t files < <(find "$REPO_ROOT/.github/workflows" "$REPO_ROOT/templates" -path '*/.github/workflows/*.yml')
  [ "${#files[@]}" -gt 0 ]
  run node "$BATS_TEST_DIRNAME/helpers/unread-renovate-comments.js" "$REPO_ROOT/renovate.json" "$REPO_ROOT" "${files[@]}"
  echo "$output"
  [ "$status" -eq 0 ]
}
