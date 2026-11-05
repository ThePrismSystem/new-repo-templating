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

@test "assert_no_placeholders ignores a Python virtual environment" {
  mkdir -p "$WORK/.venv/lib"
  echo "{{{NRAND}}}" > "$WORK/.venv/lib/sqldata.py"
  run assert_no_placeholders "$WORK"
  [ "$status" -eq 0 ]
}

@test "assert_visibility passes when public scaffold has both workflows" {
  mkdir -p "$WORK/.github/workflows"
  touch "$WORK/.github/workflows/codeql.yml" "$WORK/.github/workflows/scorecard.yml"
  run assert_visibility "$WORK" public
  [ "$status" -eq 0 ]
}

@test "assert_visibility fails when public scaffold is missing a workflow" {
  mkdir -p "$WORK/.github/workflows"
  touch "$WORK/.github/workflows/codeql.yml"
  run assert_visibility "$WORK" public
  [ "$status" -eq 1 ]
  [[ "$output" == *"scorecard.yml"* ]]
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

@test "every addon names an executable check script" {
  local meta check
  for meta in "$REPO_ROOT"/templates/addons/*/addon.json; do
    check="$(jq -r '.check' "$meta")"
    [ "$check" != "null" ]
    local found=false dir
    for dir in "$(dirname "$meta")/files" "$REPO_ROOT"/templates/common/*/files; do
      if [[ -x "$dir/$check" ]]; then found=true; fi
    done
    [ "$found" = "true" ]
  done
}

@test "--help exits zero" {
  run "$REPO_ROOT/verify.sh" --help
  [ "$status" -eq 0 ]
  [[ "$output" == *"--skip-audit"* ]]
}

@test "unknown addon is rejected" {
  run "$REPO_ROOT/verify.sh" --addon typescript-cobol
  [ "$status" -ne 0 ]
  [[ "$output" == *"Unknown addon"* ]]
}

# bats test_tags=slow,addon:typescript-node
@test "typescript scaffold lints clean after a coverage run" {
  "$REPO_ROOT/setup.sh" demo "$WORK/proj" --addon typescript-node >/dev/null
  cd "$WORK/proj" || return 1
  run scripts/check-typescript.sh test
  [ "$status" -eq 0 ]
  [ -d coverage ]
  run scripts/check-typescript.sh lint
  [ "$status" -eq 0 ]
}

# bats test_tags=slow,addon:javascript
@test "javascript lint rejects let in a file under the es5Script preset" {
  "$REPO_ROOT/setup.sh" demo "$WORK/proj" --addon javascript >/dev/null
  cd "$WORK/proj" || return 1
  run scripts/check-javascript.sh lint
  [ "$status" -eq 0 ]
  mkdir -p es5
  printf 'var greeting = "hi";\nlet count = 1;\n' >es5/legacy.js
  run scripts/check-javascript.sh lint
  [ "$status" -ne 0 ]
  [[ "$output" == *"es5/legacy.js"* ]]
}

# bats test_tags=slow,addon:javascript
@test "javascript lint accepts a JXA run handler and the osascript globals" {
  "$REPO_ROOT/setup.sh" demo "$WORK/proj" --addon javascript >/dev/null
  cd "$WORK/proj" || return 1
  mkdir -p jxa
  cat >jxa/notify.js <<'JXA'
function run(argv) {
  const app = Application.currentApplication();
  app.includeStandardAdditions = true;
  delay(0.1);
  app.displayNotification(argv.join(" "), { withTitle: ObjC.unwrap($("demo")) });
}
JXA
  run pnpm exec eslint jxa --max-warnings 0
  [ "$status" -eq 0 ]
  printf 'process.exit(1);\n' >jxa/node-only.js
  run pnpm exec eslint jxa --max-warnings 0
  [ "$status" -ne 0 ]
  [[ "$output" == *"'process' is not defined"* ]]
}

# bats test_tags=slow,addon:python
@test "python lint rejects subprocess with shell=True" {
  "$REPO_ROOT/setup.sh" demo "$WORK/proj" --addon python >/dev/null
  cd "$WORK/proj" || return 1
  run scripts/check-python.sh lint
  [ "$status" -eq 0 ]
  printf 'import subprocess\n\n\ndef run(cmd):\n    return subprocess.call(cmd, shell=True)\n' >src/run.py
  run scripts/check-python.sh lint
  [ "$status" -ne 0 ]
  [[ "$output" == *"S602"* ]]
}

# bats test_tags=slow,addon:python
@test "python test counts a module no test imports against the floor" {
  "$REPO_ROOT/setup.sh" demo "$WORK/proj" --addon python >/dev/null
  cd "$WORK/proj" || return 1
  run scripts/check-python.sh test
  [ "$status" -eq 0 ]
  [ -f coverage/python.xml ]
  python3 -I -c 'print("\n".join(f"def f{i}(x):\n    if x:\n        return {i}\n    return -{i}\n\n" for i in range(20)))' >src/untested.py
  run scripts/check-python.sh test
  [ "$status" -ne 0 ]
  [[ "$output" == *"untested.py"* ]]
}

# bats test_tags=slow,addon:shell
@test "shell lint rejects an unquoted variable in a starter script" {
  "$REPO_ROOT/setup.sh" demo "$WORK/proj" --addon shell >/dev/null
  cd "$WORK/proj" || return 1
  run scripts/check-shell.sh lint
  [ "$status" -eq 0 ]
  cat >>src/greet.sh <<'SH'

shout() {
  echo $1
}
SH
  run scripts/check-shell.sh lint
  [ "$status" -ne 0 ]
  [[ "$output" == *"SC2086"* ]]
}

# bats test_tags=slow,addon:lua
@test "lua lint rejects an accidental global" {
  "$REPO_ROOT/setup.sh" demo "$WORK/proj" --addon lua >/dev/null
  cd "$WORK/proj" || return 1
  run scripts/check-lua.sh lint
  [ "$status" -eq 0 ]
  printf 'local M = {}\n\nfunction M.count()\n  total = 1\n  return total\nend\n\nreturn M\n' >src/counter.lua
  run scripts/check-lua.sh lint
  [ "$status" -ne 0 ]
  # luacheck colors the variable name, so match around it.
  [[ "$output" == *"src/counter.lua"*"non-standard global variable"*"total"* ]]
}

# bats test_tags=slow,addon:lua
@test "lua test counts a module no test loads against the floor" {
  "$REPO_ROOT/setup.sh" demo "$WORK/proj" --addon lua >/dev/null
  cd "$WORK/proj" || return 1
  run scripts/check-lua.sh test
  [ "$status" -eq 0 ]
  [ -f coverage/lcov.info ]
  {
    echo "local M = {}"
    for i in $(seq 1 20); do
      printf 'function M.f%d(x)\n  if x then\n    return %d\n  end\n  return -%d\nend\n' "$i" "$i" "$i"
    done
    echo "return M"
  } >src/untested.lua
  run scripts/check-lua.sh test
  [ "$status" -ne 0 ]
  [[ "$output" == *"floor 80%"* ]]
}
