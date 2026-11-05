import eslintCommentsPlugin from "@eslint-community/eslint-plugin-eslint-comments/configs";
import eslintConfigPrettier from "eslint-config-prettier";
import importPlugin from "eslint-plugin-import-x";
import reactHooksPlugin from "eslint-plugin-react-hooks";
import reactRefreshPlugin from "eslint-plugin-react-refresh";
import unicornPlugin from "eslint-plugin-unicorn";
import tseslint from "typescript-eslint";

export default tseslint.config(
  {
    ignores: [
      "**/dist/**",
      "**/build/**",
      "**/node_modules/**",
      "**/vite.config.ts",
      "**/test-setup.ts",
    ],
  },
  ...tseslint.configs.strictTypeChecked,
  {
    languageOptions: {
      parserOptions: {
        // The project service only auto-discovers `tsconfig.json`, which scopes
        // itself to `src`. Root-level tooling files live in tsconfig.node.json,
        // so point the service at it explicitly or they lint without type info.
        projectService: {
          allowDefaultProject: ["vitest.config.ts"],
          defaultProject: "tsconfig.node.json",
        },
      },
    },
  },
  eslintCommentsPlugin.recommended,
  {
    plugins: {
      "import-x": importPlugin,
      unicorn: unicornPlugin,
      "react-hooks": reactHooksPlugin,
      "react-refresh": reactRefreshPlugin,
    },
    rules: {
      // Ban all eslint-disable comments — fix the violation, don't suppress it
      "@eslint-community/eslint-comments/no-use": "error",

      // No `as any`
      "@typescript-eslint/no-explicit-any": "error",

      // No `as unknown as T`
      "no-restricted-syntax": [
        "error",
        {
          selector: "TSAsExpression > TSAsExpression[typeAnnotation.type='TSUnknownKeyword']",
          message:
            "Force-casting via 'as unknown as Type' is forbidden. Fix the underlying type mismatch instead.",
        },
        {
          selector: "TSTypeAssertion > TSTypeAssertion[typeAnnotation.type='TSUnknownKeyword']",
          message:
            "Force-casting via '<Type><unknown>' is forbidden. Fix the underlying type mismatch instead.",
        },
      ],

      // No @ts-ignore or @ts-expect-error
      "@typescript-eslint/ban-ts-comment": [
        "error",
        {
          "ts-ignore": true,
          "ts-expect-error": true,
        },
      ],

      // No non-null assertion
      "@typescript-eslint/no-non-null-assertion": "error",

      // No var
      "no-var": "error",

      // No floating promises
      "@typescript-eslint/no-floating-promises": "error",

      // No swallowed errors
      "no-empty": "error",

      // No console.log in production
      "no-console": ["error", { allow: ["info", "warn", "error"] }],

      // Disabled for React — impractical for JSX components
      "@typescript-eslint/explicit-module-boundary-types": "off",

      // Exhaustive switch
      "@typescript-eslint/switch-exhaustiveness-check": "error",

      // Disabled for React — too noisy in UI code
      "@typescript-eslint/no-magic-numbers": "off",

      // Import organization
      "import-x/order": [
        "error",
        {
          groups: ["builtin", "external", "internal", "parent", "sibling", "index", "type"],
          "newlines-between": "always",
          alphabetize: { order: "asc", caseInsensitive: true },
        },
      ],

      // No unnecessary conditions
      "@typescript-eslint/no-unnecessary-condition": "error",

      // Prefer nullish coalescing
      "@typescript-eslint/prefer-nullish-coalescing": "error",

      // Prefer optional chain
      "@typescript-eslint/prefer-optional-chain": "error",

      // No misused promises
      "@typescript-eslint/no-misused-promises": "error",

      // Require await
      "@typescript-eslint/require-await": "error",

      // Strict equality
      eqeqeq: "error",

      // Curly braces required
      curly: "error",

      // React hooks rules
      ...reactHooksPlugin.configs.recommended.rules,

      // React refresh — only export components
      "react-refresh/only-export-components": ["warn", { allowConstantExport: true }],
    },
  },
  {
    files: [
      "**/*.test.ts",
      "**/*.test.tsx",
      "**/*.spec.ts",
      "**/*.spec.tsx",
      "**/__tests__/**/*.{ts,tsx}",
    ],
    rules: {
      "@typescript-eslint/no-unsafe-assignment": "off",
      "@typescript-eslint/no-unsafe-member-access": "off",
      "@typescript-eslint/ban-ts-comment": [
        "error",
        {
          "ts-ignore": true,
          "ts-expect-error": "allow-with-description",
          minimumDescriptionLength: 10,
        },
      ],
    },
  },
  {
    files: ["**/*.js", "**/*.cjs"],
    ...tseslint.configs.disableTypeChecked,
    rules: {
      ...tseslint.configs.disableTypeChecked.rules,
      "@typescript-eslint/no-require-imports": "off",
    },
  },
  {
    files: ["**/*.d.ts"],
    ...tseslint.configs.disableTypeChecked,
  },
  eslintConfigPrettier,
);
