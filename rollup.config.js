import commonjs from '@rollup/plugin-commonjs';
import eslint from '@rollup/plugin-eslint';
import path from 'path';
import resolve from '@rollup/plugin-node-resolve';
import sass from 'sass';
import scss from 'rollup-plugin-scss';
import svelte from 'rollup-plugin-svelte';
import {babel} from '@rollup/plugin-babel';
import {terser} from 'rollup-plugin-terser';

const assetsDir = process.env.ROLLUP_ASSETS_DIR || path.resolve(__dirname, 'assets');
const isDev = process.env.NODE_ENV !== 'production';
const fileKey = isDev ? 'development' : parseInt((new Date().getTime() / 1000), 10).toString(16);
const outDir = process.env.ROLLUP_OUT_DIR || path.resolve(__dirname, 'dist');

const config = {
  input: path.resolve(assetsDir, 'index.js'),
  output: {format: 'iife', sourcemap: true, file: path.resolve(outDir, `convos.${fileKey}.js`)},
  plugins: [],
  watch: {clearScreen: false},
};

const outputStyle = isDev ? null : 'compressed';
config.plugins.push(scss({outputStyle, sass, sourceMap: true, watch: './assets/sass'}));
config.plugins.push(eslint({exclude: ['node_modules/**', '**/*.css', '**/*.sass'], fix: process.env.ESLINT_FIX ? true : false}));
config.plugins.push(svelte({}));
config.plugins.push(commonjs());
config.plugins.push(resolve({browser: true}));
config.plugins.push(babel({babelHelpers: 'runtime'}));

if (!isDev) config.plugins.push(terser());

export default config;
