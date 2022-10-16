import {defineConfig} from 'vite'
import {svelte} from '@sveltejs/vite-plugin-svelte'

export default defineConfig(({mode}) => {
  const output = {};
  if (mode === 'development') {
    output.assetFileNames = 'assets/[name].development[extname]';
    output.chunkFileNames = 'assets/[name].development[extname]';
    output.entryFileNames = 'assets/[name].development.js';
  }

  return {
    build: {
      assetsInlineLimit: 0,
      cssCodeSplit: false,
      emptyOutDir: false,
      outDir: 'public',
      minify: mode === 'development' ? false : 'esbuild',
      rollupOptions: {input: './assets/convos.js', output},
    },
    plugins: [svelte()],
    publicDir: 'public',
    test: {
      environment: 'jsdom',
    },
  };
})
