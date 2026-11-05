# typescript-node

A Node.js backend, CLI or library in TypeScript. Can't be combined with
`typescript-react` or `javascript`, since each one owns `package.json`.

## What it adds

- TypeScript 6.0 in strict mode, ES2022 target, Bundler resolution
- ESLint 10 with typescript-eslint's strict type-checked rules, import ordering
  and unicorn, plus a ban on `eslint-disable` comments, `as any` and
  `as unknown as` casts
- Prettier, knip for unused code and dependencies, cspell
- Vitest with v8 coverage, failing under 80% of lines, functions, branches and
  statements
- t3-env for typed environment variables, validated with Zod
- Husky: pre-commit formats and lints staged files, pre-push runs typecheck,
  lint and unit tests, commit-msg runs commitlint
- pnpm settings in `pnpm-workspace.yaml`

## Checks

`scripts/check-typescript.sh <step>` runs each check. CI runs one step per job,
and every job is a required check.

| Step | CI job | Runs |
|---|---|---|
| `lint` | `typescript-lint` | Prettier, ESLint with zero warnings, `pnpm audit` |
| `typecheck` | `typescript-typecheck` | `tsc` over `src` and the tooling files |
| `test` | `typescript-test` | Unit tests with coverage, uploaded to Codecov under the `typescript` flag |
| `quality` | `typescript-quality` | knip, cspell |
| `build` | `typescript-build` | `tsc -p tsconfig.build.json` |

CodeQL scans it as `javascript-typescript`.

## In the generated project

| Command | What it does |
|---|---|
| `pnpm dev` | Run `src/index.ts` with watch mode |
| `pnpm build` | Build to `dist/` |
| `pnpm test` | Run every test |
| `pnpm test:unit` | Run the tests that aren't `*.integration.test.ts` |
| `pnpm lint:fix`, `pnpm format:fix` | Fix what ESLint and Prettier can |
