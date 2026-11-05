#!/usr/bin/env bats

bats_require_minimum_version 1.5.0

setup() {
  REPO_ROOT="$(cd "$BATS_TEST_DIRNAME/.." && pwd)"
  WORK="$(mktemp -d)"
  FAKE_GH_LOG="$WORK/gh.log"
  FAKE_GH_RESPONSES="$WORK/responses"
  export FAKE_GH_LOG FAKE_GH_RESPONSES
  mkdir -p "$FAKE_GH_RESPONSES"
  : >"$FAKE_GH_LOG"
  PATH="$BATS_TEST_DIRNAME/fixtures/fake-gh:$PATH"
  unset CODECOV_TOKEN

  R="$FAKE_GH_RESPONSES"
  echo '{"permissions": {"admin": true}, "default_branch": "main", "allow_merge_commit": false, "allow_squash_merge": true, "allow_rebase_merge": true, "has_issues": true, "security_and_analysis": {"secret_scanning": {"status": "disabled"}}}' >"$R/GET_repos_o_r.json"
  echo '[]' >"$R/GET_repos_o_r_rulesets.json"
  echo '{"message": "Branch not protected"}' >"$R/GET_repos_o_r_branches_main_protection.json"
  echo 404 >"$R/GET_repos_o_r_branches_main_protection.status"
  echo 404 >"$R/GET_repos_o_r_vulnerability-alerts.status"
  echo '{"enabled": true, "paused": false}' >"$R/GET_repos_o_r_automated-security-fixes.json"
  echo '{"enabled": false}' >"$R/GET_repos_o_r_private-vulnerability-reporting.json"
  echo '{"id": 7}' >"$R/POST_repos_o_r_rulesets.json"

  MANIFEST="$WORK/manifest.json"
  write_manifest_fixture public true '{}'
}

teardown() {
  rm -rf "$WORK"
}

write_manifest_fixture() {
  local visibility="$1" coverage="$2" settings="$3"
  jq -n --arg v "$visibility" --argjson c "$coverage" --argjson s "$settings" '{
    addons: ["alpha"],
    visibility: $v,
    codeScanning: ($v == "public"),
    coverage: $c,
    requiredChecks: [
      {context: "gitleaks", integration_id: 15368},
      {context: "alpha-test", integration_id: 15368},
      {context: "codecov/patch", integration_id: 254}
    ],
    repoSettings: $s
  }' >"$MANIFEST"
}

apply() {
  run "$REPO_ROOT/apply-settings.sh" o/r --manifest "$MANIFEST" "$@"
}

# Prints the JSON body sent with the first call matching "<METHOD> <endpoint>".
body_of() {
  awk -v call="$1" '$0 == call { getline; sub(/^BODY /, ""); print; exit }' "$FAKE_GH_LOG"
}

writes() {
  grep -E '^(PATCH|PUT|POST|DELETE) |^secret ' "$FAKE_GH_LOG" || true
}

@test "dry run makes only GET calls" {
  apply --dry-run
  [ "$status" -eq 0 ]
  [ -z "$(writes)" ]
  [[ "$output" == *"would PATCH repos/o/r"* ]]
  [[ "$output" == *"would POST repos/o/r/rulesets"* ]]
}

@test "patches repo settings to merge commits only" {
  apply
  [ "$status" -eq 0 ]
  run jq -c '{allow_merge_commit, allow_squash_merge, allow_rebase_merge, merge_commit_title, merge_commit_message}' <<<"$(body_of "PATCH repos/o/r")"
  [ "$output" = '{"allow_merge_commit":true,"allow_squash_merge":false,"allow_rebase_merge":false,"merge_commit_title":"PR_TITLE","merge_commit_message":"PR_BODY"}' ]
  run jq -c '{allow_auto_merge, delete_branch_on_merge, allow_update_branch, web_commit_signoff_required, has_issues, has_discussions, has_wiki, has_projects}' <<<"$(body_of "PATCH repos/o/r")"
  [ "$output" = '{"allow_auto_merge":true,"delete_branch_on_merge":true,"allow_update_branch":true,"web_commit_signoff_required":true,"has_issues":true,"has_discussions":true,"has_wiki":false,"has_projects":false}' ]
  run jq -r '.security_and_analysis.secret_scanning_push_protection.status' <<<"$(body_of "PATCH repos/o/r")"
  [ "$output" = "enabled" ]
}

@test "repoSettings in the manifest override defaults" {
  write_manifest_fixture public true '{"has_issues": false, "has_discussions": false}'
  apply
  [ "$status" -eq 0 ]
  run jq -c '{has_issues, has_discussions, allow_merge_commit}' <<<"$(body_of "PATCH repos/o/r")"
  [ "$output" = '{"has_issues":false,"has_discussions":false,"allow_merge_commit":true}' ]
}

@test "turns on Dependabot alerts and private reporting, and turns off Dependabot security PRs" {
  apply
  [ "$status" -eq 0 ]
  grep -qx 'PUT repos/o/r/vulnerability-alerts' "$FAKE_GH_LOG"
  grep -qx 'DELETE repos/o/r/automated-security-fixes' "$FAKE_GH_LOG"
  grep -qx 'PUT repos/o/r/private-vulnerability-reporting' "$FAKE_GH_LOG"
}

@test "creates the main ruleset when none exists" {
  apply
  [ "$status" -eq 0 ]
  local ruleset
  ruleset="$(grep -A1 -x 'POST repos/o/r/rulesets' "$FAKE_GH_LOG" | grep '"name":"main"' | sed 's/^BODY //')"
  run jq -c '[.rules[].type]' <<<"$ruleset"
  [ "$output" = '["deletion","non_fast_forward","required_signatures","pull_request","required_status_checks","code_scanning"]' ]
  run jq -c '.rules[] | select(.type == "pull_request") | .parameters | {required_approving_review_count, dismiss_stale_reviews_on_push, required_review_thread_resolution, allowed_merge_methods}' <<<"$ruleset"
  [ "$output" = '{"required_approving_review_count":0,"dismiss_stale_reviews_on_push":true,"required_review_thread_resolution":true,"allowed_merge_methods":["merge"]}' ]
  run jq -c '.conditions.ref_name.include, .bypass_actors' <<<"$ruleset"
  [ "$output" = "$(printf '["~DEFAULT_BRANCH"]\n[]')" ]
}

@test "required checks carry integration ids" {
  apply
  local ruleset
  ruleset="$(grep -A1 -x 'POST repos/o/r/rulesets' "$FAKE_GH_LOG" | grep '"name":"main"' | sed 's/^BODY //')"
  run jq -c '.rules[] | select(.type == "required_status_checks") | .parameters | {strict_required_status_checks_policy, checks: [.required_status_checks[] | "\(.context)=\(.integration_id)"]}' <<<"$ruleset"
  [ "$output" = '{"strict_required_status_checks_policy":false,"checks":["gitleaks=15368","alpha-test=15368","codecov/patch=254"]}' ]
}

@test "code scanning rule blocks high alerts and errors" {
  apply
  local ruleset
  ruleset="$(grep -A1 -x 'POST repos/o/r/rulesets' "$FAKE_GH_LOG" | grep '"name":"main"' | sed 's/^BODY //')"
  run jq -c '.rules[] | select(.type == "code_scanning") | .parameters.code_scanning_tools' <<<"$ruleset"
  [ "$output" = '[{"tool":"CodeQL","security_alerts_threshold":"high_or_higher","alerts_threshold":"errors"}]' ]
}

@test "private manifest omits the code_scanning rule" {
  write_manifest_fixture private true '{}'
  apply
  [ "$status" -eq 0 ]
  local ruleset
  ruleset="$(grep -A1 -x 'POST repos/o/r/rulesets' "$FAKE_GH_LOG" | grep '"name":"main"' | sed 's/^BODY //')"
  run jq -r '[.rules[].type] | index("code_scanning")' <<<"$ruleset"
  [ "$output" = "null" ]
}

@test "creates the release tags ruleset" {
  apply
  [ "$status" -eq 0 ]
  local ruleset
  ruleset="$(grep -A1 -x 'POST repos/o/r/rulesets' "$FAKE_GH_LOG" | grep '"name":"release tags"' | sed 's/^BODY //')"
  run jq -c '{target, include: .conditions.ref_name.include, rules: [.rules[].type]}' <<<"$ruleset"
  [ "$output" = '{"target":"tag","include":["refs/tags/v*"],"rules":["deletion","non_fast_forward","update"]}' ]
}

@test "updates the main ruleset in place by id" {
  echo '[{"id": 42, "name": "main", "target": "branch"}]' >"$FAKE_GH_RESPONSES/GET_repos_o_r_rulesets.json"
  echo '{"id": 42, "name": "main", "target": "branch", "enforcement": "active", "conditions": {"ref_name": {"include": ["refs/heads/main"], "exclude": []}}, "bypass_actors": [], "rules": [{"type": "deletion"}]}' \
    >"$FAKE_GH_RESPONSES/GET_repos_o_r_rulesets_42.json"
  apply
  [ "$status" -eq 0 ]
  grep -qx 'PUT repos/o/r/rulesets/42' "$FAKE_GH_LOG"
  run grep -A1 -x 'POST repos/o/r/rulesets' "$FAKE_GH_LOG"
  [[ "$output" != *'"name":"main"'* ]]
}

@test "skips a write when nothing differs" {
  "$REPO_ROOT/apply-settings.sh" o/r --manifest "$MANIFEST" >/dev/null
  # Make every GET answer with what was just written, as GitHub would.
  jq -s '.[0] * .[1] | .security_and_analysis |= with_entries(.value = {status: .value.status})' \
    "$FAKE_GH_RESPONSES/GET_repos_o_r.json" <(body_of "PATCH repos/o/r") >"$WORK/repo.json"
  mv "$WORK/repo.json" "$FAKE_GH_RESPONSES/GET_repos_o_r.json"
  rm "$FAKE_GH_RESPONSES/GET_repos_o_r_vulnerability-alerts.status"
  echo '{"enabled": false, "paused": false}' >"$FAKE_GH_RESPONSES/GET_repos_o_r_automated-security-fixes.json"
  echo '{"enabled": true}' >"$FAKE_GH_RESPONSES/GET_repos_o_r_private-vulnerability-reporting.json"
  local main tags
  main="$(grep -A1 -x 'POST repos/o/r/rulesets' "$FAKE_GH_LOG" | grep '"name":"main"' | sed 's/^BODY //')"
  tags="$(grep -A1 -x 'POST repos/o/r/rulesets' "$FAKE_GH_LOG" | grep '"name":"release tags"' | sed 's/^BODY //')"
  echo '[{"id": 1, "name": "main", "target": "branch"}, {"id": 2, "name": "release tags", "target": "tag"}]' \
    >"$FAKE_GH_RESPONSES/GET_repos_o_r_rulesets.json"
  # GitHub adds parameters nobody set; they mustn't count as a difference.
  jq '.id = 1 | (.rules[] | select(.type == "pull_request") | .parameters.required_reviewers) = []' <<<"$main" \
    >"$FAKE_GH_RESPONSES/GET_repos_o_r_rulesets_1.json"
  jq '.id = 2' <<<"$tags" >"$FAKE_GH_RESPONSES/GET_repos_o_r_rulesets_2.json"
  : >"$FAKE_GH_LOG"

  apply
  [ "$status" -eq 0 ]
  [ -z "$(writes)" ]
  [[ "$output" == *"up to date"* ]]
}

@test "stops at the first API failure with gh's message" {
  echo '{"message": "Validation Failed"}' >"$FAKE_GH_RESPONSES/PATCH_repos_o_r.json"
  echo 422 >"$FAKE_GH_RESPONSES/PATCH_repos_o_r.status"
  apply
  [ "$status" -ne 0 ]
  [[ "$output" == *"Validation Failed"* ]]
  [ "$(tail -2 "$FAKE_GH_LOG" | head -1)" = "PATCH repos/o/r" ]
}

@test "fails before any write when gh auth status fails" {
  echo 1 >"$FAKE_GH_RESPONSES/auth.status"
  apply
  [ "$status" -ne 0 ]
  [[ "$output" == *"gh auth login"* ]]
  [ -z "$(writes)" ]
}

@test "fails before any write without admin on the repo" {
  jq '.permissions.admin = false' "$FAKE_GH_RESPONSES/GET_repos_o_r.json" >"$WORK/repo.json"
  mv "$WORK/repo.json" "$FAKE_GH_RESPONSES/GET_repos_o_r.json"
  apply
  [ "$status" -ne 0 ]
  [[ "$output" == *"admin"* ]]
  [ -z "$(writes)" ]
}

@test "warns about another ruleset on the default branch" {
  echo '[{"id": 9, "name": "old protection", "target": "branch"}]' >"$FAKE_GH_RESPONSES/GET_repos_o_r_rulesets.json"
  apply
  [ "$status" -eq 0 ]
  [[ "$output" == *"Warning"*"old protection"* ]]
  run grep -E '^(PUT|DELETE) repos/o/r/rulesets/9$' "$FAKE_GH_LOG"
  [ "$status" -ne 0 ]
}

@test "warns about classic branch protection on the default branch" {
  rm "$FAKE_GH_RESPONSES/GET_repos_o_r_branches_main_protection.status"
  echo '{"required_status_checks": null}' >"$FAKE_GH_RESPONSES/GET_repos_o_r_branches_main_protection.json"
  apply
  [ "$status" -eq 0 ]
  [[ "$output" == *"Warning"*"branch protection"* ]]
}

@test "errors without a manifest or --addon" {
  echo 404 >"$FAKE_GH_RESPONSES/GET_repos_o_r_contents_.github_repo-standards.json.status"
  run "$REPO_ROOT/apply-settings.sh" o/r
  [ "$status" -ne 0 ]
  [[ "$output" == *"repo-standards.json"* && "$output" == *"--addon"* ]]
  [ -z "$(writes)" ]
}

@test "reads the manifest from the repo when none is given" {
  base64 -w0 "$MANIFEST" | jq -R '{content: .}' >"$FAKE_GH_RESPONSES/GET_repos_o_r_contents_.github_repo-standards.json.json"
  run "$REPO_ROOT/apply-settings.sh" o/r --dry-run
  [ "$status" -eq 0 ]
  [[ "$output" == *"would POST repos/o/r/rulesets"* ]]
}

@test "sets CODECOV_TOKEN only when present and coverage is on" {
  apply
  run ! grep -q '^secret' "$FAKE_GH_LOG"
  : >"$FAKE_GH_LOG"
  CODECOV_TOKEN=abc123 apply
  [ "$status" -eq 0 ]
  grep -qx 'secret set CODECOV_TOKEN --repo o/r' "$FAKE_GH_LOG"
  grep -qx 'BODY abc123' "$FAKE_GH_LOG"
  [[ "$output" != *"abc123"* ]]
  write_manifest_fixture public false '{}'
  : >"$FAKE_GH_LOG"
  CODECOV_TOKEN=abc123 apply
  run ! grep -q '^secret' "$FAKE_GH_LOG"
}

@test "ends by listing the steps it can't do itself" {
  apply
  [[ "$output" == *"Renovate"* && "$output" == *"Codecov"* ]]
}
