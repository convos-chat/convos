import sveltePreprocess from 'svelte-preprocess'

export default {
  preprocess: sveltePreprocess(),
  build: {
    manifest: true,
    minify: 'esbuild',
    sourcemap: true,
  },
};
