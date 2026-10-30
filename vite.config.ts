import { defineConfig } from 'vite'
import react from '@vitejs/plugin-react'

// In Docker, Caddy routes /api to the backend before requests reach Vite.
// Without Docker (Codespaces, Termux, plain laptop), Vite proxies /api itself.
const apiTarget = process.env.API_PROXY_TARGET || 'http://127.0.0.1:8000'

export default defineConfig({
  plugins: [react()],
  server: {
    host: '0.0.0.0',
    port: 5173,
    allowedHosts: true,
    proxy: {
      '/api': {
        target: apiTarget,
        changeOrigin: true,
        rewrite: (path) => path.replace(/^[/]api/, ''),
      },
    },
  },
})
