import babel from 'rollup-plugin-babel';
import commonjs from '@rollup/plugin-commonjs';
import cssnano from 'cssnano';
import postcss from 'rollup-plugin-postcss'
import postcssPresetEnv from 'postcss-preset-env';
import resolve from '@rollup/plugin-node-resolve';
import svelte from 'rollup-plugin-svelte';
import visualizer from 'rollup-plugin-visualizer';
import {eslint} from 'rollup-plugin-eslint';
import {terser} from 'rollup-plugin-terser';

// The html plugin generates a file that M::P::Webpack reads to generate the
// correct output when calling <%= asset 'convos.js' %> and
// <%= asset 'convos.css' %>
import html from 'rollup-plugin-bundle-html';

// The output file need to contain a hash for M::P::Webpack to find it
const dest = process.env.WEBPACK_OUT_DIR || 'public/asset';
const development = process.env.NODE_ENV == 'development' || (process.env.ROLLUP_WATCH ? true : false);
const ts = parseInt((new Date().getTime() / 1000), 10).toString(16);

function outPath(name) {
  const filename = name.replace(/\[hash\]/, development ? 'development' : ts);
  return [dest, filename].join('/');
}

// Define default plugins
const plugins = [
  svelte({dev: development}),
  resolve(),
  commonjs(),
  postcss({extract: true, plugins: [postcssPresetEnv(), cssnano()]}),
];

if (development) plugins.unshift(eslint({exclude: ['assets/sass/**', 'node_modules/**']}));

plugins.push(babel({
  //exclude: 'node_modules/**',
  extensions: ['.html', '.js', '.mjs', '.svelte'],
  presets: [['@babel/preset-env', {corejs: 3, debug: false, useBuiltIns: 'entry'}]],
  runtimeHelpers: true,
  plugins: ['@babel/plugin-transform-runtime'],
}));

if (!development) {
  plugins.push(visualizer({filename: 'public/docs/js-modules-visualized.html', title: 'Convos JavaScript modules visualized'}));
  plugins.push(terser());
}

plugins.push(html({
  dest,
  filename: 'webpack.' + (development ? 'development' : 'production') + '.html',
  inject: 'head',
  template: '<html><head></head><body></body></html>',
}));

// Define config
export default {
  input: 'assets/entrypoint.js',
  output: {
    // The output file need to contain a hash for M::P::Webpack to find it
    file: outPath('convos.[hash].js'),
    format: 'iife',
    name: 'convos',
    sourcemap: true,
  },
  plugins,
  watch: {
    clearScreen: false,
  },
};
