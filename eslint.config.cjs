const { defineConfig, globalIgnores } = require("eslint/config");

const svelte = require("eslint-plugin-svelte");
const parser = require("svelte-eslint-parser");
const globals = require("globals");
const js = require("@eslint/js");

const { FlatCompat } = require("@eslint/eslintrc");

const compat = new FlatCompat({
  baseDirectory: __dirname,
  recommendedConfig: js.configs.recommended,
  allConfig: js.configs.all,
});

module.exports = defineConfig([
  {
    extends: compat.extends("eslint:recommended", "plugin:svelte/recommended"),

    plugins: {
      svelte,
    },

    languageOptions: {
      sourceType: "module",
      ecmaVersion: 2020,
      parserOptions: {},

      globals: {
        ...globals.browser,
        ...globals.node,
      },
    },

    rules: {
      "no-control-regex": 0,
      "svelte/no-at-html-tags": "off",
    },
  },
  globalIgnores(["**/*.cjs"]),
  {
    files: ["**/*.svelte"],

    languageOptions: {
      parser: parser,
    },
  },
  globalIgnores([
    "**/.DS_Store",
    "**/node_modules",
    "public/assets",
    "**/pnpm-lock.yaml",
    "**/package-lock.json",
  ]),
]);
