import { defineConfig } from 'vitest/config';
import react from '@vitejs/plugin-react';
import vercel from './vercel.json';

const headers = Object.fromEntries(vercel.headers[0].headers.map((h) => [h.key, h.value]));

export default defineConfig({
  plugins: [react()],
  // Previews run under the same security headers as production.
  preview: { headers },
  build: { chunkSizeWarningLimit: 1200 },
  test: { include: ['tests/**/*.test.ts'], environment: 'node' },
});
