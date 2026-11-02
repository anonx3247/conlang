import { defineConfig } from '@playwright/test';

export default defineConfig({
  testDir: 'e2e',
  timeout: 60000,
  use: { baseURL: 'http://localhost:5199', viewport: { width: 1400, height: 900 } },
  projects: [
    { name: 'chrome', use: { channel: 'chrome' } },
    // These two have no file-link API, so they exercise the browser-storage path.
    { name: 'firefox', use: { browserName: 'firefox' }, testIgnore: /real-file/, grepInvert: /linked project file/ },
    { name: 'webkit', use: { browserName: 'webkit' }, testIgnore: /real-file/, grepInvert: /linked project file/ },
  ],
  webServer: { command: process.env.E2E_PREVIEW ? 'npx vite preview --port 5199 --strictPort' : 'npx vite --port 5199 --strictPort', url: 'http://localhost:5199', reuseExistingServer: true },
});
