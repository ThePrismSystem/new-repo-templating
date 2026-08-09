# new-repo-templating

[![Verify Templates](https://github.com/ThePrismSystem/new-repo-templating/actions/workflows/verify.yml/badge.svg)](https://github.com/ThePrismSystem/new-repo-templating/actions/workflows/verify.yml)

Reusable project templates for bootstrapping new TypeScript projects with fully
configured tooling. Run `setup.sh`, get a project with linting, formatting,
testing, type checking, git hooks, CI, and dependency automation already wired
together and verified to work as a set.

**What this is not:** a package, a CLI you install, or a GitHub template
repository. It is a directory of template files plus a shell script that copies
and parameterizes them. Nothing here is published to a registry.

This repository is published for reference and is not accepting contributions.
See [CONTRIBUTING.md](CONTRIBUTING.md) and [LICENSE](LICENSE).

## Available Flavors

### `typescript-node`

Node.js backend, CLI, or library template.

- TypeScript 6.0 with strict mode, ES2022 target, Bundler resolution
- ESLint 10 with typescript-eslint strict type checking, import ordering, unicorn, prettier compat
- Prettier with consistent formatting (semicolons, double quotes, 100 char width)
- Vitest with v8 coverage (80% thresholds)
- Husky + lint-staged (pre-commit: format + lint, pre-push: typecheck + lint + test)
- Commitlint enforcing Conventional Commits on commit-msg hook
- Knip for detecting unused code and dependencies
- cspell for spell checking source files
- t3-env for type-safe environment variables with Zod validation
- Renovate for automated dependency updates (replaces Dependabot)
- GitHub Actions CI (lint, typecheck, unit tests, quality checks in parallel)
- GitHub templates (PR template, bug report, CODEOWNERS)
- CodeQL security scanning and Gitleaks secret scanning (public repos only)

### `typescript-react`

Vite + React SPA template. Includes everything from `typescript-node` plus:

- Vite dev server and build
- React 19 with JSX transform
- eslint-plugin-react-hooks and eslint-plugin-react-refresh
- jsdom test environment with @testing-library/react, @testing-library/jest-dom, @testing-library/user-event
- rollup-plugin-visualizer for bundle analysis (`pnpm analyze`)
- CI build job that depends on lint + typecheck

## Pinned Versions

Two dependencies are deliberately held below their latest release. Both are enforced by `renovate.json`, so they will not drift silently — but if you change them by hand, read this first.

**`typescript` is pinned `~6.0.3` — the tilde is load-bearing.** `typescript-eslint` declares `peerDependencies.typescript: ">=4.8.4 <6.1.0"`, and there is no newer major line of it. A caret (`^6.0.3`) would admit 6.1.0 the day it ships and break the peer. TypeScript 7 is out for the same reason. Revisit when typescript-eslint supports the TypeScript 7 compiler API.

**`@types/node` tracks `.nvmrc`, not its own latest.** The templates run Node 24 (Active LTS), so `@types/node` stays on the 24 line. Typing against Node 26 APIs while running Node 24 produces code that compiles and then fails at runtime.

One behavior worth knowing if you touch the TypeScript pin: **TypeScript 6.0 no longer auto-includes `@types/*` packages without an explicit `types` entry.** That is why `typescript-node`'s `tsconfig.json` sets `"types": ["node"]`, and why the react template can keep Node globals out of browser code by listing `types` only in `tsconfig.node.json`. If the pin moves, re-verify that boundary rather than assuming it holds.

## Usage

```bash
./setup.sh <project-name> [target-dir] [--flavor typescript-node|typescript-react] [--visibility public|private]
```

### Examples

```bash
# Create a Node.js project in ./my-api (public, default)
./setup.sh my-api

# Create a React project in a specific directory
./setup.sh my-app /path/to/my-app --flavor typescript-react

# Create a private repo without CodeQL/Gitleaks workflows
./setup.sh my-internal-api --visibility private

# Create a library
./setup.sh my-lib ./packages/my-lib --flavor typescript-node
```

The script will:

1. Copy shared configs (`.editorconfig`, `.prettierrc.js`, `.gitignore`, GitHub templates, etc.)
2. Copy the selected flavor's files (ESLint, TypeScript, Vitest configs, CI, husky hooks, etc.)
3. If `--visibility public` (default), copy public-only workflows (CodeQL, Gitleaks)
4. Replace placeholders (`{{PROJECT_NAME}}`, `{{GITHUB_OWNER}}`, `{{YEAR}}`, etc.)
5. Run `git init`, `pnpm install`, and `husky` setup

### Visibility

| Visibility | Includes |
|---|---|
| `public` (default) | All tools + CodeQL security scanning + Gitleaks secret scanning |
| `private` | All tools except CodeQL and Gitleaks (require public repo access) |

### Placeholders

| Placeholder | Source |
|---|---|
| `{{PROJECT_NAME}}` | First argument to `setup.sh` |
| `{{GITHUB_OWNER}}` | Auto-detected from `gh api user` |
| `{{PROJECT_DESCRIPTION}}` | Default generated (editable after) |
| `{{YEAR}}` | Current year |
| `{{NODE_VERSION}}` | From `.nvmrc` in the flavor |

## Verifying Templates

The templates carry no lockfiles, so every scaffold resolves the newest release
matching each range. `verify.sh` scaffolds each flavor into a temp directory and
runs the same checks the generated project's CI runs, so template breakage is
caught here rather than by whoever next runs `setup.sh`.

It invokes those checks directly as pnpm scripts and never executes the
scaffolded workflow files, so a green run shows the template's checks pass — not
that its CI is wired up correctly. The step list is also not identical to any one
flavor's CI: `verify.sh` runs `build` for both flavors, while the node template's
CI has no build job.

```bash
./verify.sh                              # both flavors
./verify.sh --flavor typescript-react    # one flavor
./verify.sh --keep                       # leave scaffolds on disk to debug
./verify.sh --skip-audit                 # skip pnpm audit
```

Each run scaffolds twice per flavor: once private with `--no-install` for the
structural checks (no leftover `{{PLACEHOLDER}}`, correct visibility gating),
and once public with a full install for the gate itself (`format`, `lint`,
`typecheck`, coverage tests, `knip`, `spell`, `build`, `pnpm audit`).

CI runs this on every push and PR, plus weekly, so an upstream release that
breaks a template surfaces as a failed run here. Shell changes are covered by
`bats tests/` and `shellcheck`.

## Adding a New Flavor

1. Create a new directory under `templates/` (e.g., `templates/typescript-fastify`)
2. Add flavor-specific configs (ESLint, tsconfig, package.json, CI, etc.)
3. Shared files from `templates/_shared/` are copied first, then your flavor's files overlay on top
4. Use `{{PLACEHOLDER}}` syntax for any values that should be parameterized

## What's Included

| Config | Purpose |
|---|---|
| `.editorconfig` | Editor-level formatting (indent, EOL, charset) |
| `.prettierrc.js` | Code formatting rules |
| `.prettierignore` | Files excluded from formatting |
| `.npmrc` | pnpm config (auto-install-peers) |
| `.gitignore` | Standard ignores for Node/TS projects |
| `eslint.config.js` | Linting with strict TypeScript rules |
| `tsconfig.json` | TypeScript compiler config |
| `vitest.config.ts` | Test runner with coverage |
| `.husky/*` | Git hooks (pre-commit, pre-push, commit-msg) |
| `commitlint.config.js` | Conventional Commits enforcement |
| `knip.json` | Unused code/dependency detection |
| `cspell.config.yaml` | Spell checking configuration |
| `renovate.json` | Automated dependency updates |
| `.github/workflows/ci.yml` | CI pipeline (lint, typecheck, test, quality) |
| `.github/workflows/codeql.yml` | CodeQL security scanning (public only) |
| `.github/workflows/gitleaks.yml` | Secret scanning (public only) |
| `.github/` | PR template, issue templates, CODEOWNERS |

## License

This repository is licensed under the terms in [LICENSE](LICENSE): all rights
reserved. The code is readable for reference; no permission is granted to use,
copy, modify, or redistribute it.

Projects generated by `setup.sh` are a separate matter — they ship the MIT
license in `templates/*/LICENSE`, with the copyright holder set to whoever runs
the script. Scaffolding a project with this tool puts no restriction on the code
you build.
