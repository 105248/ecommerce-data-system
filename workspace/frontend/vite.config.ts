import { defineConfig } from 'vite'
import react from '@vitejs/plugin-react'

// 同源静态托管：构建产物由 FastAPI 8001 挂载（零 CORS），base 用相对路径
export default defineConfig({
  plugins: [react()],
  base: './',
  build: {
    outDir: 'dist',
    sourcemap: false,
  },
  server: {
    port: 5173,
    proxy: {
      '/api': 'http://127.0.0.1:8001',
    },
  },
})
