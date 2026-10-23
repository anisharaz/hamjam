import { defineConfig } from 'vite';
import react from '@vitejs/plugin-react';

export default defineConfig({
  plugins: [react()],
  // `npm run dev` proxies the APK link to a locally running relay
  server: { proxy: { '/download': 'http://localhost:8080', '/healthz': 'http://localhost:8080' } },
});
