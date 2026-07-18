import { fileURLToPath, URL } from 'node:url'
import vue from '@vitejs/plugin-vue'
import { defineConfig } from 'vite'
import { ui } from '@sil/ui/vite'

export default defineConfig({
  plugins: [vue(), ui()],
  resolve: {
    alias: {
      '@': fileURLToPath(new URL('./src', import.meta.url)),
    },
  },
  css: {
    preprocessorOptions: {
      scss: {
        additionalData: `@use "@/styles/_mixins" as *;`,
      },
    },
  },
  optimizeDeps: {
    // @sil/ui's barrel pulls its Markdown component, which pulls highlight.js
    // (CJS). esbuild mis-detects its default export during dev pre-bundling, so
    // force it to be optimized as an interop entry. (Rollup build is unaffected.)
    include: ['highlight.js/lib/core'],
  },
})
