import { defineConfig } from 'vite'
import { svelte } from '@sveltejs/vite-plugin-svelte'

// https://vite.dev/config/
export default defineConfig({
  plugins: [svelte()],
  server: {
    host: '0.0.0.0',
    port: 5173,
    watch: {
      usePolling: true,
    },
    proxy: {
      '/api': 'http://backend:8080',
      '/login': 'http://backend:8080',
      '/callback': 'http://backend:8080',
      '/logout': 'http://backend:8080',
    }
  }
})
