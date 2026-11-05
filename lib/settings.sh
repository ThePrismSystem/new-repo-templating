#!/usr/bin/env bash
# Repo settings, security settings and rulesets that apply-settings.sh puts in
# place. Every desired_* function reads the manifest a scaffold carries in
# .github/repo-standards.json and prints JSON in the shape GitHub's REST API
# takes.

# shellcheck disable=SC2016 # jq programs below use $variables of their own.

DEFAULT_REPO_SETTINGS='{
  "allow_merge_commit": true,
  "allow_squash_merge": false,
  "allow_rebase_merge": false,
  "merge_commit_title": "PR_TITLE",
  "merge_commit_message": "PR_BODY",
  "allow_auto_merge": true,
  "delete_branch_on_merge": true,
  "allow_update_branch": true,
  "web_commit_signoff_required": true,
  "has_issues": true,
  "has_discussions": true,
  "has_wiki": false,
  "has_projects": false,
  "security_and_analysis": {
    "secret_scanning": { "status": "enabled" },
    "secret_scanning_push_protection": { "status": "enabled" }
  }
}'

desired_repo_settings() {
  jq --argjson defaults "$DEFAULT_REPO_SETTINGS" '$defaults * (.repoSettings // {})' "$1"
}

desired_main_ruleset() {
  jq '{
    name: "main",
    target: "branch",
    enforcement: "active",
    conditions: { ref_name: { include: ["~DEFAULT_BRANCH"], exclude: [] } },
    bypass_actors: [],
    rules: ([
      { type: "deletion" },
      { type: "non_fast_forward" },
      { type: "required_signatures" },
      { type: "pull_request", parameters: {
          required_approving_review_count: 0,
          dismiss_stale_reviews_on_push: true,
          require_code_owner_review: false,
          require_last_push_approval: false,
          required_review_thread_resolution: true,
          allowed_merge_methods: ["merge"]
      } },
      { type: "required_status_checks", parameters: {
          strict_required_status_checks_policy: false,
          do_not_enforce_on_create: false,
          required_status_checks: .requiredChecks
      } }
    ] + (if .codeScanning then [
      { type: "code_scanning", parameters: { code_scanning_tools: [
          { tool: "CodeQL", security_alerts_threshold: "high_or_higher", alerts_threshold: "errors" }
      ] } }
    ] else [] end))
  }' "$1"
}

desired_tag_ruleset() {
  jq -n '{
    name: "release tags",
    target: "tag",
    enforcement: "active",
    conditions: { ref_name: { include: ["refs/tags/v*"], exclude: [] } },
    bypass_actors: [],
    rules: [{ type: "deletion" }, { type: "non_fast_forward" }, { type: "update" }]
  }'
}

# Prints the current state cut down to the keys the desired state sets, so
# fields GitHub fills in itself never count as a difference. Rules are matched
# by type, and lists whose order GitHub doesn't keep are sorted.
JQ_COMPARABLE='
  def keep($template):
    if ($template | type) == "object" and type == "object" then
      with_entries(.key as $k | select($template | has($k)) | .value |= keep($template[$k]))
    else . end;
  def tidy:
    if has("rules") then
      .rules |= (sort_by(.type) | map(
        if .parameters.required_status_checks then .parameters.required_status_checks |= sort_by(.context) else . end
        | if .parameters.allowed_merge_methods then .parameters.allowed_merge_methods |= sort else . end))
    else . end;
  ($desired | tidy) as $want
  | ($current | keep($desired)
      | if has("rules") then
          .rules |= map(. as $rule
            | ([$desired.rules[] | select(.type == $rule.type)] | first) as $template
            | if $template then keep($template) else . end)
        else . end
      | tidy) as $have
  | if $which == "desired" then $want else $have end
'

comparable() {
  local which="$1" desired="$2" current="$3"
  jq -nS --arg which "$which" --argjson desired "$desired" --argjson current "$current" "$JQ_COMPARABLE"
}

# Prints a diff of the current and desired state; succeeds when they match.
same_state() {
  local desired="$1" current="$2"
  diff <(comparable current "$desired" "$current") <(comparable desired "$desired" "$current") \
    --label current --label desired -u
}

warn() {
  echo "Warning: $*" >&2
}

fail() {
  echo "Error: $*" >&2
  exit 1
}

# Runs one write unless this is a dry run. The optional body goes on stdin.
write() {
  local method="$1" endpoint="$2" body="${3:-}"
  if [[ "$DRY_RUN" == "true" ]]; then
    echo "would $method $endpoint"
    return 0
  fi
  if [[ -n "$body" ]]; then
    gh api -X "$method" "$endpoint" --input - <<<"$body" >/dev/null || fail "$method $endpoint failed"
  else
    gh api -X "$method" "$endpoint" --silent || fail "$method $endpoint failed"
  fi
}

apply_repo_settings() {
  local repo="$1" manifest="$2" current="$3"
  local desired changes
  desired="$(desired_repo_settings "$manifest")"
  echo "== repo settings"
  if changes="$(same_state "$desired" "$current")"; then
    echo "up to date"
    return 0
  fi
  if [[ "$DRY_RUN" == "true" ]]; then
    echo "$changes"
  fi
  write PATCH "repos/$repo" "$desired"
}

apply_security_settings() {
  local repo="$1"
  echo "== security"
  if gh api "repos/$repo/vulnerability-alerts" --silent 2>/dev/null; then
    echo "Dependabot alerts: up to date"
  else
    write PUT "repos/$repo/vulnerability-alerts"
  fi
  local fixes reporting
  fixes="$(gh api "repos/$repo/automated-security-fixes")" || fail "can't read Dependabot security updates on $repo"
  reporting="$(gh api "repos/$repo/private-vulnerability-reporting")" || fail "can't read private vulnerability reporting on $repo"
  # Renovate opens the security updates, so Dependabot's own PRs stay off.
  if [[ "$(jq -r '.enabled' <<<"$fixes")" == "true" ]]; then
    write DELETE "repos/$repo/automated-security-fixes"
  else
    echo "Dependabot security updates: up to date"
  fi
  if [[ "$(jq -r '.enabled' <<<"$reporting")" == "true" ]]; then
    echo "private vulnerability reporting: up to date"
  else
    write PUT "repos/$repo/private-vulnerability-reporting"
  fi
}

apply_ruleset() {
  local repo="$1" rulesets="$2" desired="$3"
  local name id current changes
  name="$(jq -r '.name' <<<"$desired")"
  echo "== ruleset '$name'"
  id="$(jq -r --arg name "$name" '[.[] | select(.name == $name)][0].id // empty' <<<"$rulesets")"
  if [[ -z "$id" ]]; then
    if [[ "$DRY_RUN" == "true" ]]; then
      jq . <<<"$desired"
    fi
    write POST "repos/$repo/rulesets" "$desired"
    return 0
  fi
  current="$(gh api "repos/$repo/rulesets/$id")" || fail "GET repos/$repo/rulesets/$id failed"
  if changes="$(same_state "$desired" "$current")"; then
    echo "up to date"
    return 0
  fi
  if [[ "$DRY_RUN" == "true" ]]; then
    echo "$changes"
  fi
  write PUT "repos/$repo/rulesets/$id" "$desired"
}

apply_codecov_token() {
  local repo="$1" manifest="$2"
  if [[ "$(jq -r '.coverage' "$manifest")" != "true" || -z "${CODECOV_TOKEN:-}" ]]; then
    return 0
  fi
  echo "== secrets"
  if [[ "$DRY_RUN" == "true" ]]; then
    echo "would set the CODECOV_TOKEN secret"
    return 0
  fi
  printf '%s' "$CODECOV_TOKEN" | gh secret set CODECOV_TOKEN --repo "$repo" || fail "setting CODECOV_TOKEN failed"
}

# Applies everything, stopping at the first write GitHub refuses.
apply_settings() {
  local repo="$1" manifest="$2"
  local current branch rulesets

  current="$(gh api "repos/$repo")" || fail "can't read $repo"
  if [[ "$(jq -r '.permissions.admin' <<<"$current")" != "true" ]]; then
    fail "changing settings and rulesets on $repo needs admin access, and this gh login doesn't have it"
  fi
  branch="$(jq -r '.default_branch' <<<"$current")"
  rulesets="$(gh api "repos/$repo/rulesets")" || fail "can't list the rulesets on $repo"

  # Older protection can block what this standard allows (a squash-only rule
  # stops merge commits), so it's named here but never removed.
  if gh api "repos/$repo/branches/$branch/protection" --silent 2>/dev/null; then
    warn "$branch also has classic branch protection; check it doesn't conflict with the 'main' ruleset"
  fi
  local other
  while IFS= read -r other; do
    warn "ruleset '$other' also targets branches; check it doesn't conflict with the 'main' ruleset"
  done < <(jq -r '.[] | select(.target == "branch" and .name != "main") | .name' <<<"$rulesets")

  apply_repo_settings "$repo" "$manifest" "$current"
  apply_security_settings "$repo"
  apply_ruleset "$repo" "$rulesets" "$(desired_main_ruleset "$manifest")"
  apply_ruleset "$repo" "$rulesets" "$(desired_tag_ruleset)"
  apply_codecov_token "$repo" "$manifest"
}
