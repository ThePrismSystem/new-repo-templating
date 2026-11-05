# javascript

Plain JavaScript on Node.js, with no build step. Can't be combined with
`typescript-node` or `typescript-react`, since each one owns `package.json`.

## What it adds

- ESLint 10 with the recommended rules, `eqeqeq`, `curly`, `no-var`,
  `prefer-const` and a ban on `eslint-disable` comments
- Two presets in `eslint.config.js` for scripts that don't run on Node:
  - `es5Script` for engines that stop at ES5: no modules, no `let` or `const`
  - `jxa` for JavaScript for Automation (`osascript -l JavaScript`): the
    automation globals instead of Node's, and `run` never counts as unused

  Files under `es5/` and `jxa/` get them. Change `ES5_SCRIPTS` and
  `JXA_SCRIPTS` at the top of the config to point them somewhere else.
- Prettier and cspell
- `node --test` with its built-in coverage, failing under 80% of lines. It
  counts the files your tests load, so a file no test imports doesn't show up
  in the report or on Codecov
- Husky: pre-commit formats and lints staged files, pre-push runs lint and
  the tests, commit-msg runs commitlint
- pnpm settings in `pnpm-workspace.yaml`

## Checks

`scripts/check-javascript.sh <step>` runs each check. CI runs one step per job,
and every job is a required check.

| Step | CI job | Runs |
|---|---|---|
| `lint` | `javascript-lint` | Prettier, ESLint with zero warnings, cspell, `pnpm audit` |
| `test` | `javascript-test` | `node --test` with coverage, uploaded to Codecov under the `javascript` flag |

CodeQL scans it as `javascript-typescript`.

## In the generated project

| Command | What it does |
|---|---|
| `pnpm test` | Run the tests in `src/` |
| `pnpm test:coverage` | Run them with coverage, writing `coverage/lcov.info` |
| `pnpm lint:fix`, `pnpm format:fix` | Fix what ESLint and Prettier can |
