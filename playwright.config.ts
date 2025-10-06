import { defineConfig, devices } from '@playwright/test';
export default defineConfig({
  testDir: './tests',
  timeout: 60_000,
  fullyParallel: true,
  reporter: 'list',
  use: { timezoneId: 'Asia/Manila', locale: 'en-PH', colorScheme: 'dark' },
  webServer: { command: 'pnpm start', url: 'http://localhost:3001', reuseExistingServer: true },
  projects: [ { name: 'chromium', use: { ...devices['Desktop Chrome'], viewport: { width: 1280, height: 900 } } } ]
});
