import { fileURLToPath } from "node:url";

import { includeIgnoreFile } from "@eslint/compat";
import commentsPlugin from "@eslint-community/eslint-plugin-eslint-comments/configs";
import js from "@eslint/js";
import eslintConfigPrettier from "eslint-config-prettier";
import globals from "globals";

// Scripts that don't run on Node get one of the presets below in place of the
// Node settings. Point these globs at wherever those scripts live.
const ES5_SCRIPTS = ["es5/**/*.js"];
const JXA_SCRIPTS = ["jxa/**/*.js"];

// Plain scripts for engines that stop at ES5: no modules, no let or const.
export const es5Script = {
  languageOptions: {
    ecmaVersion: 5,
    sourceType: "script",
  },
  rules: {
    // Top-level declarations in a script are globals that other scripts on
    // the same page or host can use.
    "no-unused-vars": ["error", { vars: "local" }],
  },
};

// JavaScript for Automation, run with `osascript -l JavaScript`. These scripts
// see the automation globals instead of Node's, and osascript calls `run`, so
// it never counts as unused.
export const jxa = {
  languageOptions: {
    ecmaVersion: "latest",
    sourceType: "script",
    globals: {
      $: "readonly",
      Application: "readonly",
      console: "readonly",
      delay: "readonly",
      ObjC: "readonly",
      Path: "readonly",
    },
  },
  rules: {
    "no-unused-vars": ["error", { varsIgnorePattern: "^run$" }],
  },
};

export default [
  // Skip what git ignores, such as a Python virtual environment in a stacked repo.
  includeIgnoreFile(fileURLToPath(new URL(".gitignore", import.meta.url))),
  {
    ignores: ["**/coverage/**", "**/node_modules/**"],
  },
  js.configs.recommended,
  commentsPlugin.recommended,
  {
    rules: {
      // Fix the violation instead of turning the rule off.
      "@eslint-community/eslint-comments/no-use": "error",
      curly: "error",
      eqeqeq: "error",
    },
  },
  {
    files: ["**/*.{js,mjs,cjs}"],
    ignores: [...ES5_SCRIPTS, ...JXA_SCRIPTS],
    languageOptions: {
      ecmaVersion: "latest",
      sourceType: "module",
      globals: globals.node,
    },
    rules: {
      "no-console": ["error", { allow: ["info", "warn", "error"] }],
      "no-var": "error",
      "prefer-const": "error",
    },
  },
  {
    files: ["**/*.cjs"],
    languageOptions: {
      sourceType: "commonjs",
    },
  },
  { files: ES5_SCRIPTS, ...es5Script },
  { files: JXA_SCRIPTS, ...jxa },
  eslintConfigPrettier,
];
