# {{PROJECT_NAME}}

{{PROJECT_DESCRIPTION}}

## Prerequisites

- [Node.js](https://nodejs.org/) v{{NODE_VERSION}}+
- [pnpm](https://pnpm.io/)

## Getting Started

```bash
# Install dependencies
pnpm install

# Start development server
pnpm dev
```

## Scripts

| Command              | Description                    |
| -------------------- | ------------------------------ |
| `pnpm dev`           | Start Vite dev server          |
| `pnpm build`         | Build for production           |
| `pnpm preview`       | Preview production build       |
| `pnpm lint`          | Run ESLint                     |
| `pnpm lint:fix`      | Run ESLint with auto-fix       |
| `pnpm typecheck`     | Run TypeScript type checking   |
| `pnpm format`        | Check formatting with Prettier |
| `pnpm format:fix`    | Fix formatting with Prettier   |
| `pnpm test`          | Run all tests                  |
| `pnpm test:coverage` | Run tests with coverage        |
| `pnpm test:watch`    | Run tests in watch mode        |

## Contributing

1. Create a feature branch
2. Make your changes
3. Ensure `pnpm typecheck && pnpm lint && pnpm test` pass
4. Open a pull request

## License

[MIT](LICENSE)
