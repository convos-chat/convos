import collectSass from 'rollup-plugin-collect-sass'
import commonjs from 'rollup-plugin-commonjs';
import resolve from 'rollup-plugin-node-resolve';
import svelte from 'rollup-plugin-svelte';
import {eslint} from 'rollup-plugin-eslint';
import {terser} from 'rollup-plugin-terser';

// The html plugin generates a file that M::P::Webpack reads to generate the
// correct output when calling <%= asset 'convos.js' %> and
// <%= asset 'convos.css' %>
import html from 'rollup-plugin-bundle-html';

// The output file need to contain a hash for M::P::Webpack to find it
const dest = process.env.WEBPACK_OUT_DIR || 'public/asset';
const production = !process.env.ROLLUP_WATCH;
function outPath(fn) {
  const filename = production ? fn : fn.replace(/\[hash\]/, 'development');
  return [dest, filename].join('/');
}

export default {
  input: 'assets/entrypoint.js',
  output: {
    // The output file need to contain a hash for M::P::Webpack to find it
    file: outPath('convos.[hash].js'),
    format: 'iife',
    name: 'convos',
    sourcemap: true,
  },
  plugins: [
    !production && eslint({exclude: ['assets/sass/**', 'node_modules/**']}),

    // https://svelte.dev/ specific plugin config
    svelte({
      dev: !production,
      css: (css) => {
        css.write(outPath('convos.[hash].css'));
      },
    }),

    resolve(),
    commonjs(),
    collectSass({extract: outPath('convos.[hash].css')}),
    production && terser(),

    html({
      dest,
      filename: 'webpack.' + (production ? 'production' : 'development') + '.html',
      inject: 'head',
      template: '<html><head></head><body></body></html>',
    }),
  ],
  watch: {
    clearScreen: false,
  },
};
