import {defineConfig} from 'vite'
import {svelte} from '@sveltejs/vite-plugin-svelte'

export default defineConfig(({mode}) => {
  const output = {};
  if (mode === 'development') {
    output.assetFileNames = 'assets/[name].development[extname]';
    output.chunkFileNames = 'assets/[name].development[extname]';
    output.entryFileNames = 'assets/[name].development.js';
  }
  else {
    output.assetFileNames = 'assets/[name].[hash][extname]';
    output.chunkFileNames = 'assets/[name].[hash][extname]';
    output.entryFileNames = 'assets/[name].[hash].js';
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
    publicDir: 'does/not/matter',
    resolve: {
      alias: {
        '../font/fa-5.15.4': './public/font/fa-5.15.4',
        '../font/google': './public/font/google',
      },
    },
    test: {
      environment: 'jsdom',
    },
  };
})
