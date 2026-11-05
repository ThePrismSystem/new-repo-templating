#!/usr/bin/env bash
# Functions that compose a scaffold from templates/base and templates/addons.
# setup.sh and apply-settings.sh source this file; every function reads the
# templates from $TEMPLATES_DIR and changes no shell options.

# GitHub App ids that ruleset status checks are pinned to, so a check with the
# same name from another app can't satisfy them.
ACTIONS_APP_ID=15368
CODECOV_APP_ID=254

# Keeps the first occurrence of each array element, in order. $x is a jq
# variable, so the single quotes are deliberate.
# shellcheck disable=SC2016
JQ_UNIQ_ORDERED='def uniq_ordered: reduce .[] as $x ([]; if any(.[]; . == $x) then . else . + [$x] end);'

addon_dir() {
  printf '%s/addons/%s' "$TEMPLATES_DIR" "$1"
}

# Prints the addon.json documents of the given addons as one JSON array.
addon_metas() {
  local name files=()
  for name in "$@"; do
    files+=("$(addon_dir "$name")/addon.json")
  done
  if ((${#files[@]} == 0)); then
    echo '[]'
    return 0
  fi
  jq -s '.' "${files[@]}"
}

# Prints each addon once, in argument order. Fails on an unknown addon or on
# two addons where either declares a conflict with the other.
resolve_addons() {
  local name seen=() existing duplicate
  for name in "$@"; do
    if [[ ! -f "$(addon_dir "$name")/addon.json" ]]; then
      echo "Error: unknown addon '$name'" >&2
      return 1
    fi
    duplicate=false
    for existing in "${seen[@]}"; do
      if [[ "$existing" == "$name" ]]; then
        duplicate=true
      fi
    done
    if [[ "$duplicate" == "false" ]]; then
      seen+=("$name")
    fi
  done

  local conflict
  conflict="$(addon_metas "${seen[@]}" | jq -r '
    . as $m
    | [range(0; length) as $i | range($i + 1; length) as $j
        | select((($m[$i].conflicts // []) | any(. == $m[$j].name))
            or (($m[$j].conflicts // []) | any(. == $m[$i].name)))
        | "\($m[$i].name)\t\($m[$j].name)"]
    | first // empty')"
  if [[ -n "$conflict" ]]; then
    echo "Error: addons '${conflict%%$'\t'*}' and '${conflict#*$'\t'}' can't be combined" >&2
    return 1
  fi

  if ((${#seen[@]} > 0)); then
    printf '%s\n' "${seen[@]}"
  fi
}

# Prints the templates/common directories the given addons use, each once.
resolve_common() {
  addon_metas "$@" | jq -r "$JQ_UNIQ_ORDERED"' [.[].common // [] | .[]] | uniq_ordered | .[]'
}

# Writes the base Renovate config with each addon's packageRules and
# customManagers appended.
merge_renovate() {
  local out="$1"
  shift
  local name fragments=("$TEMPLATES_DIR/base/renovate.json")
  for name in "$@"; do
    if [[ -f "$(addon_dir "$name")/renovate.json" ]]; then
      fragments+=("$(addon_dir "$name")/renovate.json")
    fi
  done
  jq -s '
    reduce .[1:][] as $f (.[0];
      (if $f.packageRules then .packageRules += $f.packageRules else . end)
      | (if $f.customManagers then .customManagers += $f.customManagers else . end))
  ' "${fragments[@]}" >"$out"
}

# Writes .gitignore from base and each addon that has a fragment, each under a
# "# <name>" header.
build_gitignore() {
  local out="$1"
  shift
  {
    echo "# base"
    cat "$TEMPLATES_DIR/base/gitignore"
    local name
    for name in "$@"; do
      if [[ -f "$(addon_dir "$name")/gitignore" ]]; then
        echo ""
        echo "# $name"
        cat "$(addon_dir "$name")/gitignore"
      fi
    done
  } >"$out"
}

# Writes codecov.yml when at least one addon measures coverage.
build_codecov() {
  local out="$1"
  shift
  local metas
  metas="$(addon_metas "$@" | jq '[.[] | select(.coverage)]')"
  if [[ "$(jq 'length' <<<"$metas")" == "0" ]]; then
    return 0
  fi

  local builds
  builds="$(jq '[.[].coverage.uploads] | add' <<<"$metas")"
  {
    cat <<EOF
# Codecov holds the lines a pull request changes to 90%. Each test job also
# fails on its own when what it measures drops under 80% of lines.
coverage:
  status:
    project: off
    patch:
      default:
        target: 90%

# The patch status waits for every upload, so it is never worked out from a
# partial run.
codecov:
  notify:
    after_n_builds: $builds
comment:
  after_n_builds: $builds

# An upload that doesn't arrive keeps the last commit's numbers instead of
# counting as no coverage.
flag_management:
  default_rules:
    carryforward: true

component_management:
  individual_components:
EOF
    jq -r '.[] | "    - component_id: \(.name)\n      name: \(.name)\n      paths:",
      (.coverage.paths[] | "        - \"\(.)\"")' <<<"$metas"
  } >"$out"
}

# Prints the CodeQL languages as a YAML flow list, or nothing for a private
# repo, where code scanning isn't available.
codeql_languages() {
  local visibility="$1"
  shift
  if [[ "$visibility" != "public" ]]; then
    return 0
  fi
  addon_metas "$@" | jq -r "$JQ_UNIQ_ORDERED"' ["actions"] + [.[].codeql // empty] | uniq_ordered
    | "[" + join(", ") + "]"'
}

# Prints the required status checks as a JSON array of {context, integration_id}.
required_checks() {
  local visibility="$1"
  shift
  local languages='[]'
  if [[ "$visibility" == "public" ]]; then
    languages="$(addon_metas "$@" | jq -c "$JQ_UNIQ_ORDERED"' ["actions"] + [.[].codeql // empty] | uniq_ordered')"
  fi
  addon_metas "$@" | jq \
    --slurpfile base "$TEMPLATES_DIR/base/addon.json" \
    --argjson languages "$languages" \
    --argjson actions "$ACTIONS_APP_ID" \
    --argjson codecov "$CODECOV_APP_ID" \
    "$JQ_UNIQ_ORDERED"'
    . as $addons
    | ($base[0].checks + [$addons[].checks[]] + [$languages[] | "analyze (\(.))"] | uniq_ordered
        | map({context: ., integration_id: $actions}))
      + (if any($addons[]; .coverage) then [{context: "codecov/patch", integration_id: $codecov}] else [] end)'
}

# Writes .github/repo-standards.json, which apply-settings.sh reads.
write_manifest() {
  local out="$1" visibility="$2"
  shift 2
  local checks
  checks="$(required_checks "$visibility" "$@")"
  addon_metas "$@" | jq \
    --arg visibility "$visibility" \
    --argjson checks "$checks" \
    '{
      addons: [.[].name],
      visibility: $visibility,
      codeScanning: ($visibility == "public"),
      coverage: any(.[]; .coverage),
      requiredChecks: $checks,
      repoSettings: {}
    }' >"$out"
}
