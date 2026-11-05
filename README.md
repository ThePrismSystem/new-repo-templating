# new-repo-templating

[![Verify Templates](https://github.com/ThePrismSystem/new-repo-templating/actions/workflows/verify.yml/badge.svg)](https://github.com/ThePrismSystem/new-repo-templating/actions/workflows/verify.yml)

The standard every new repository starts from. A base gives every repo the same
settings, checks and dependency automation, and addons add the linting, tests and
coverage for each language or kind of repo. `setup.sh` scaffolds a project from the
base and the addons you pick. `apply-settings.sh` then configures the GitHub
repository to match: merge settings, the `main` ruleset and its required checks,
signed commits, and the security features.

It's a directory of templates and shell scripts. There's no package to install, and
it isn't a GitHub template repository.

[docs/standards.md](docs/standards.md) lists each rule in the standard, what enforces
it, and why.

This repository is published for reference and is not accepting contributions. See
[CONTRIBUTING.md](CONTRIBUTING.md) and [LICENSE](LICENSE).

## Starting a repo

1. Scaffold the project:

   ```bash
   ./setup.sh my-tool --addon python --addon shell
   ```

2. Create the repository and push the first commit. `setup.sh` prints this command
   with your owner filled in:

   ```bash
   cd my-tool
   gh repo create <owner>/my-tool --public --source . --push
   ```

3. Apply the settings. Run it with `--dry-run` first to see each change.

   ```bash
   ./apply-settings.sh <owner>/my-tool --dry-run
   ./apply-settings.sh <owner>/my-tool
   ```

4. Install the Renovate and Codecov GitHub apps on the repository. The script can't
   do this, so it prints the links when it finishes. If an addon measures coverage,
   copy the repository's upload token from Codecov and run the script again with
   `CODECOV_TOKEN` set, which stores the token as a repo secret.

## setup.sh

```bash
./setup.sh <project-name> [target-dir] [--addon <name>]... [--visibility public|private] [--no-install]
```

```bash
# A Node service
./setup.sh my-api --addon typescript-node

# A React app in a directory of your choosing
./setup.sh my-app ~/git/my-app --addon typescript-react

# Private scripts for macOS and Windows
./setup.sh my-scripts --addon shell --addon powershell --addon javascript --visibility private
```

The script copies the base files, then each addon's files and the shared files its
addons need. From each addon's fragments it assembles `.gitignore`, `renovate.json`,
`codecov.yml` when an addon measures coverage, and `.github/repo-standards.json`,
the manifest `apply-settings.sh` reads. It fills in the placeholders, runs
`git init`, then runs each addon's setup steps, such as `pnpm install` or creating a
Python virtual environment. `--no-install` skips those setup steps.

| Placeholder | Value |
|---|---|
| `{{PROJECT_NAME}}` | The first argument |
| `{{GITHUB_OWNER}}` | The login `gh api user` returns |
| `{{PROJECT_DESCRIPTION}}` | A default sentence to edit afterwards |
| `{{YEAR}}` | The current year, for `LICENSE` |
| `{{CODEQL_LANGUAGES}}` | `actions` plus each addon's CodeQL language |

## Addons

| Addon | For | Lint | Tests | CodeQL |
|---|---|---|---|---|
| [`typescript-node`](templates/addons/typescript-node/README.md) | Node services, CLIs and libraries | ESLint strict type-checked, Prettier, tsc, knip, cspell | Vitest, 80% coverage | `javascript-typescript` |
| [`typescript-react`](templates/addons/typescript-react/README.md) | Vite and React apps | As above, plus the React hooks rules and a production build | Vitest with jsdom, 80% coverage | `javascript-typescript` |
| [`javascript`](templates/addons/javascript/README.md) | Node scripts, ES5 scripts and JavaScript for Automation | ESLint with presets for ES5 and JXA, Prettier, cspell | `node --test`, 80% of lines | `javascript-typescript` |
| [`python`](templates/addons/python/README.md) | Python 3.13 modules and scripts | ruff check and ruff format, with dev requirements pinned by hash | unittest under coverage.py, 80% with branch coverage | `python` |
| [`lua`](templates/addons/lua/README.md) | Lua 5.4 | luacheck, lua-language-server | busted with luacov, 80% of lines | none |
| [`powershell`](templates/addons/powershell/README.md) | Modules for PowerShell 7 and Windows PowerShell 5.1 | PSScriptAnalyzer with InjectionHunter's rules | Pester 6 on both PowerShells, 80% coverage | none |
| [`shell`](templates/addons/shell/README.md) | Bash scripts | shellcheck, shfmt | bats | none |
| [`docker`](templates/addons/docker/README.md) | Container images | hadolint, Trivy's misconfiguration scan | Trivy scan of the built image | none |

Each addon's README covers its config, its CI jobs and how to fix what its checks
report.

The three Node addons each own `package.json`, so a repo takes at most one of them
and `setup.sh` rejects the others. The rest stack with anything. CI scaffolds python,
lua, powershell and javascript into one repo and runs every check to make sure they
still do.

### Visibility

Public is the default. `--visibility private` leaves out what needs code scanning,
which GitHub only offers free on public repositories: CodeQL, Scorecard, the SARIF
uploads, and the ruleset's code scanning rule. The tools behind those uploads still
fail the job on a finding.

## apply-settings.sh

```bash
./apply-settings.sh <owner/repo> [--manifest <path>] [--addon <name>]... [--visibility public|private] [--dry-run]
```

The script reads `.github/repo-standards.json` from the repository and applies:

- Merge commits only, titled and described from the pull request, with auto-merge,
  branch deletion on merge, and web commit sign-off
- Secret scanning with push protection, Dependabot alerts, and private vulnerability
  reporting
- A `main` ruleset requiring signed commits, a pull request, resolved review threads
  and the manifest's checks, plus CodeQL's results on public repos
- A `release tags` ruleset that stops `v*` tags from being moved or deleted

It creates or updates each ruleset by name and leaves other rulesets alone. It warns
when classic branch protection or another branch ruleset could conflict with `main`'s. `--dry-run` prints
each change against the current state and makes none of them. For a repo with no
manifest, pass `--addon` flags and the script works one out. You need admin rights
on the repository.

## Verifying the templates

The templates carry no lockfiles, so a scaffold resolves the newest release in each
version range, and an upstream release can break a template without any change here.
`verify.sh` catches that:

```bash
./verify.sh                                # every addon, one at a time
./verify.sh --addon lua                    # one addon
./verify.sh --combo python,lua,javascript  # addons stacked in one scaffold
./verify.sh --keep                         # leave the scaffolds on disk
./verify.sh --skip-audit                   # skip dependency audits
```

For each addon it scaffolds twice. A private scaffold without installs checks the
structure: no `{{PLACEHOLDER}}` left behind, and no public-only workflows. A public
scaffold with installs runs the addon's check script, the same one its CI jobs call,
then commits and runs the base checks. The addon's toolchain has to be on your PATH.

The `Verify Templates` workflow runs one job per addon, one for the stacked scaffold
and one for Windows PowerShell 5.1, on every pull request and weekly.

The unit tests for the scripts are in `tests/`:

```bash
bats --filter-tags '!slow' tests/
```

Tests tagged `slow` scaffold a project and need an addon's toolchain, so each runs in
that addon's verify job.

This repository follows the standard too, as a public repo with the shell addon. Its
manifest adds the verify jobs to the required checks.

## Adding an addon

An addon lives in `templates/addons/<name>/`:

- `addon.json`: the description, conflicting addons, shared directories from
  `templates/common/` it needs, its CodeQL language, the CI job names it adds as
  required checks, its coverage flag and upload count, its setup steps, and its check
  script
- `files/`: copied into the project as is, including `scripts/check-<name>.sh` and
  `.github/workflows/<name>.yml`
- `gitignore` and `renovate.json`: fragments merged into the project's files
- `README.md`

The check script takes one step name per CI job, plus `all`. Then add the addon to
the matrix in `.github/workflows/verify.yml`, with its toolchain, and give it tests
in `tests/setup.bats` and `tests/verify.bats`.

## Pinned versions

Two dependencies are held below their latest release on purpose. This repo's
`renovate.json` holds both, so Renovate won't move them, but read this before
changing them by hand.

`typescript` is pinned to `~6.0.3`, and the tilde matters. `typescript-eslint`
declares `peerDependencies.typescript: ">=4.8.4 <6.1.0"`, and it has no newer major
line. A caret (`^6.0.3`) would take 6.1.0 the day it ships and break the peer, and
TypeScript 7 is out for the same reason. Revisit this when typescript-eslint supports
the TypeScript 7 compiler API. Generated TypeScript projects carry the same cap in
their own `renovate.json`.

`@types/node` follows `.nvmrc` rather than its own latest. The templates run Node 24,
the active LTS, so `@types/node` stays on the 24 line. Typing against Node 26 APIs
while running Node 24 gives code that compiles and then fails at runtime.

If you move the TypeScript pin, note that TypeScript 6.0 stopped including `@types/*`
packages without an explicit `types` entry. That's why `typescript-node`'s
`tsconfig.json` sets `"types": ["node"]`, and why the React template keeps Node
globals out of browser code by listing `types` only in `tsconfig.node.json`. Check
that boundary again after the move.

## License

This repository is licensed under the terms in [LICENSE](LICENSE): all rights
reserved. The code is readable for reference, and no permission is granted to use,
copy, modify, or redistribute it.

Projects generated by `setup.sh` are a separate matter. They ship the MIT license
from `templates/base/files/LICENSE`, with the copyright holder set to whoever runs
the script, so scaffolding a project puts no restriction on the code you build.
