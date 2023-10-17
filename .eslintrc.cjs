module.exports = {
	root: true,
	extends: ['eslint:recommended', 'plugin:svelte/recommended'],
	plugins: ['svelte'],
	ignorePatterns: ['*.cjs'],
	overrides: [{files: ['*.svelte'], parser: 'svelte-eslint-parser'}],
	parserOptions: {
		sourceType: 'module',
		ecmaVersion: 2020
	},
	env: {
		browser: true,
		es2017: true,
		node: true
	},
  rules: {
    "no-control-regex": 0
  }
};
