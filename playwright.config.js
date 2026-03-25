// @ts-check
const { defineConfig } = require('@playwright/test');

const BASE_URL = process.env.TEST_BASE_URL || 'https://car-detector-833e5.web.app';

module.exports = defineConfig({
  testDir: './e2e',
  outputDir: './test-results',
  timeout: 30000,
  retries: 0,
  use: {
    baseURL: BASE_URL,
    screenshot: 'on',
    trace: 'on-first-retry',
    viewport: { width: 1280, height: 720 },
  },
  reporter: [
    ['html', { outputFolder: 'playwright-report', open: 'never' }],
    ['json', { outputFile: 'test-results/results.json' }],
    ['list'],
  ],
  projects: [
    {
      name: 'desktop-chrome',
      use: { browserName: 'chromium' },
    },
    {
      name: 'mobile',
      use: {
        browserName: 'chromium',
        viewport: { width: 375, height: 812 },
        isMobile: true,
      },
    },
  ],
});
