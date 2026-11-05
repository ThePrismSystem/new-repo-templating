# The standard

Every repository built from these templates follows the rules below. Each rule is
enforced by a CI check that the `main` ruleset requires, by a ruleset, or by a setting
`apply-settings.sh` applies. Check names are the CI job names.

## Changes to `main`

| Rule | Enforced by | Why |
|---|---|---|
| Every change arrives through a pull request | `main` ruleset: pull request rule | The required checks run on every change before it lands, Renovate's included. |
| No approvals needed, but every review thread is resolved before merging | Pull request rule: 0 approvals, thread resolution required | A solo maintainer can't approve their own PR, and an open review comment still blocks the merge. |
| Approvals are dismissed when new commits are pushed | Pull request rule | An approval covers the code it saw. |
| Merge commits only, titled and described from the pull request | Repo settings, and the ruleset's allowed merge methods | `main` keeps each commit as its author signed it, and the merge commit's subject is the PR title, which `conventional-commits` checks. |
| Every commit on `main` is signed | Ruleset: `required_signatures` | A commit is tied to a key its author holds. Renovate signs its commits through `platformCommit`. |
| `main` can't be deleted or force-pushed | Ruleset: `deletion`, `non_fast_forward` | Merged history can't be rewritten or lost. |
| Every job the base and the addons add must pass | Ruleset: required status checks, from `.github/repo-standards.json` | A scaffold's check names match its jobs, so each job has to pass before a PR merges. Each check is tied to the GitHub Actions app, so a status with the same name from anywhere else doesn't count. |
| A branch doesn't have to be up to date with `main` to merge | Ruleset: strict status checks off | Requiring it would rerun every check after each merge. The update-branch button is on for when it matters. |
| CodeQL alerts of high severity or worse, and CodeQL errors, block the merge | Ruleset: code scanning rule (public repos) | A new vulnerability has to be fixed before it can reach `main`. |
| Release tags (`v*`) can't be deleted, moved or force-pushed | `release tags` ruleset | A published version keeps pointing at the code it was built from. |

## Repository and security settings

`apply-settings.sh` applies these, and running it again changes only what has drifted.

| Rule | Why |
|---|---|
| Secret scanning with push protection | GitHub rejects a push that contains a token in a format it recognizes, before the token is public. |
| Dependabot alerts on, Dependabot security updates off | Renovate opens every update PR, security fixes included, so each update arrives once and in one format. |
| Private vulnerability reporting on, and `SECURITY.md` points to it | Reports stay private until a fix ships. |
| Commits made on the web need a sign-off | A commit made in GitHub's editor still records who made it. |
| Branches are deleted on merge, auto-merge is on | Renovate's grouped updates merge as soon as the required checks pass, and merged branches don't pile up. |
| Wiki and projects off | Docs live in the repo, next to the code they describe. |

## Workflows

Every workflow in a scaffold follows these rules.

| Rule | Enforced by | Why |
|---|---|---|
| `permissions: {}` at the top, and each job asks for only what it needs | zizmor | A compromised step can only do what its own job was allowed to. |
| Every action pinned to a full commit SHA, with the version in a comment | zizmor; Renovate updates the SHA and comment together | A tag can be moved to different code, and a SHA can't. |
| `persist-credentials: false` on every checkout | zizmor | The token doesn't stay in `.git/config` for later steps or uploaded artifacts to read. |
| No `pull_request_target` trigger | zizmor | It runs a fork's code with a token that can write to the repo. |
| Tools downloaded in CI are checked against a SHA-256 | `sha256sum --check` in each install step; tests in this repo | A replaced release asset fails the job before it runs. |
| Package installs don't run dependency scripts in a job that can write to code scanning | How those jobs install: wheels pinned by hash, or release downloads checked by hash | Code from a dependency never runs with that token. |
| SARIF uploads are skipped on pull requests from forks | An `if:` on each upload | A fork's token can't write to code scanning, so the upload would fail the job. |
| Every tool CI installs by version carries a `# renovate:` comment naming where its versions come from | Renovate's custom managers; a test in this repo fails on a comment no manager reads | Renovate keeps the version current, and the hash or commit beside it. |
| Workflows are valid, and their `run:` scripts pass shellcheck | actionlint | A typo in an expression fails here instead of silently skipping a step. |

## Base checks

Every repo runs these, from `lint.yml` and `codeql.yml`.

| Check | What it does | Why |
|---|---|---|
| `gitleaks` | Scans the whole git history for secrets | It catches formats GitHub doesn't, and a secret committed earlier in a branch and then deleted. |
| `zizmor` | Audits the workflows for security problems | The workflow rules above. Findings go to code scanning on public repos. |
| `actionlint` | Lints the workflows | Catches broken expressions, unknown inputs and shell mistakes in `run:` blocks. |
| `typos` | Spell checks code and docs | Typos in names and docs cost readers time, and this tool rarely flags real words. |
| `markdownlint` | Lints Markdown | Docs keep one style and render as written. |
| `conventional-commits` | Checks the PR title and the subject of every commit in the PR | A merge commit takes the PR title and keeps the branch's commits, so both have to follow the format to keep `main`'s history conventional. |
| `analyze (<language>)` | CodeQL with the `security-extended` queries, for `actions` and each addon's language, on PRs and weekly | Finds injection, unsafe deserialization and the like in the code and in the workflows. Public repos only. |

Two more workflows run without being required checks. Scorecard checks the repo's
supply-chain practices on each push to `main` and weekly, with results in code
scanning. `links` runs lychee over the Markdown on PRs that touch it and weekly, and
isn't required because an external site going down shouldn't block unrelated PRs.

## Dependency updates

Renovate keeps every pinned version current. Actions are pinned by SHA, tools by
version and hash, and packages by lockfile or hashed requirements.

| Rule | Why |
|---|---|
| Updates come before 9am on Mondays, at most 10 open at a time | One batch a week is easy to review. |
| A release has to be 7 days old before Renovate proposes it | A release that's pulled or compromised in its first days never reaches the repo. |
| Security updates skip the wait and are labelled `security` | A known vulnerability shouldn't wait a week. |
| Non-major updates to development tools come grouped in one PR, which GitHub merges once the required checks pass | The PR has to pass the same required checks as anyone else's. |
| Action updates are grouped and merged by hand | Actions run with the workflow's token, so a person reads each change. |
| Runtime versions passed to setup actions are merged by hand | They change what CI tests on. |
| Renovate's commits are signed and use `chore` Conventional Commits | So they pass the signature rule and `conventional-commits`. |

## Coverage

| Rule | Enforced by | Why |
|---|---|---|
| Each test job fails when what it measures drops under 80% of lines | Each addon's test step: Vitest thresholds, `node --test` coverage flags, coverage.py's `fail_under` (with branch coverage), `lcov-floor.sh` for luacov, Pester's coverage target | The floor holds without Codecov, and locally. |
| Lines a pull request changes are 90% covered | `codecov/patch`, a required check when an addon measures coverage | New code arrives tested, and old untested code doesn't block every PR. The project status is off for that reason. |
| Codecov waits for every upload before it reports | `after_n_builds` in `codecov.yml`, the total of every addon's uploads | The patch status is never worked out from a partial run. |
| A missing upload keeps the last commit's numbers | Carryforward flags | One skipped job doesn't read as a drop to zero. |

## Addons

Each addon's CI jobs are required checks. Its README covers what each one runs.

| Addon | Required checks |
|---|---|
| `typescript-node`, `typescript-react` | `typescript-lint`, `typescript-typecheck`, `typescript-test`, `typescript-quality`, `typescript-build` |
| `javascript` | `javascript-lint`, `javascript-test` |
| `python` | `python-lint`, `python-test` |
| `lua` | `lua-lint`, `lua-test` |
| `powershell` | `powershell-lint`, `powershell-test (ubuntu-latest)`, `powershell-test (windows-latest)` |
| `shell` | `shell-lint`, `shell-test` |
| `docker` | `docker-lint`, `docker-scan` |

Linters run at their strictest useful level and fail on warnings: ESLint with
`--max-warnings 0`, PSScriptAnalyzer at Information, lua-language-server at Warning,
shellcheck at style, hadolint at warning. The PowerShell and Docker findings also go
to code scanning on public repos.

## Visibility

A private repo built with `--visibility private` leaves out CodeQL, Scorecard, the
SARIF uploads and the ruleset's code scanning rule, because code scanning on a
private repo needs a paid GitHub plan. The tools behind the uploads still fail the
job on any finding, so the bar is the same and only the code scanning view is
missing.
