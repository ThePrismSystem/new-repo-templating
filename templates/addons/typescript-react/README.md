# typescript-react

A Vite and React single-page app in TypeScript. Can't be combined with
`typescript-node` or `javascript`, since each one owns `package.json`.

## What it adds

Everything `typescript-node` has except t3-env, plus:

- Vite for the dev server and the production build
- React 19 with the JSX transform
- eslint-plugin-react-hooks and eslint-plugin-react-refresh
- Tests in jsdom with Testing Library (`@testing-library/react`, `jest-dom`,
  `user-event`)
- rollup-plugin-visualizer for a bundle report (`pnpm analyze`)

## Checks

The same five steps and CI jobs as `typescript-node`, from
`scripts/check-typescript.sh`. The `build` step runs the typecheck and
`vite build`. Coverage goes to Codecov under the `typescript` flag, and CodeQL
scans it as `javascript-typescript`.

## In the generated project

| Command | What it does |
|---|---|
| `pnpm dev` | Start the Vite dev server |
| `pnpm build` | Typecheck, then build to `dist/` |
| `pnpm preview` | Serve the production build |
| `pnpm analyze` | Build and open the bundle report |
| `pnpm lint:fix`, `pnpm format:fix` | Fix what ESLint and Prettier can |
