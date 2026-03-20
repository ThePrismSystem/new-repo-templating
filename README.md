# new-repo-templating

Reusable project templates for bootstrapping new TypeScript projects with fully configured tooling.

All configs are derived from the an internal monorepo shared tooling packages, flattened from workspace packages into standalone, self-contained files.

## Available Flavors

### `typescript-node`

Node.js backend, CLI, or library template.

- TypeScript 5.7 with strict mode, ES2022 target, Bundler resolution
- ESLint 10 with typescript-eslint strict type checking, import ordering, unicorn, prettier compat
- Prettier with consistent formatting (semicolons, double quotes, 100 char width)
- Vitest with v8 coverage (80% thresholds)
- Husky + lint-staged (pre-commit: format + lint, pre-push: typecheck + lint + test)
- GitHub Actions CI (lint, typecheck, unit tests in parallel)
- GitHub templates (PR template, bug report, dependabot, CODEOWNERS)

### `typescript-react`

Vite + React SPA template. Includes everything from `typescript-node` plus:

- Vite dev server and build
- React 19 with JSX transform
- eslint-plugin-react-hooks and eslint-plugin-react-refresh
- jsdom test environment
- CI build job that depends on lint + typecheck

## Usage

```bash
./setup.sh <project-name> [target-dir] [--flavor typescript-node|typescript-react]
```

### Examples

```bash
# Create a Node.js project in ./my-api
./setup.sh my-api

# Create a React project in a specific directory
./setup.sh my-app /path/to/my-app --flavor typescript-react

# Create a library
./setup.sh my-lib ./packages/my-lib --flavor typescript-node
```

The script will:

1. Copy shared configs (`.editorconfig`, `.prettierrc.js`, `.gitignore`, GitHub templates, etc.)
2. Copy the selected flavor's files (ESLint, TypeScript, Vitest configs, CI, husky hooks, etc.)
3. Replace placeholders (`{{PROJECT_NAME}}`, `{{GITHUB_OWNER}}`, `{{YEAR}}`, etc.)
4. Run `git init`, `pnpm install`, and `husky` setup

### Placeholders

| Placeholder | Source |
|---|---|
| `{{PROJECT_NAME}}` | First argument to `setup.sh` |
| `{{GITHUB_OWNER}}` | Auto-detected from `gh api user` |
| `{{PROJECT_DESCRIPTION}}` | Default generated (editable after) |
| `{{YEAR}}` | Current year |
| `{{NODE_VERSION}}` | From `.nvmrc` in the flavor |

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
| `.husky/*` | Git hooks (pre-commit, pre-push) |
| `.github/workflows/ci.yml` | CI pipeline |
| `.github/` | PR template, issue templates, dependabot, CODEOWNERS |
