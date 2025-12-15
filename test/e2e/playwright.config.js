// @ts-check
const { defineConfig, devices } = require('@playwright/test');

/**
 * Playwright configuration for UI-Web E2E tests.
 * 
 * Prerequisites:
 * 1. Phoenix server running on http://localhost:4000
 * 2. Mock Gateway running on http://localhost:8081
 * 
 * Run tests:
 *   npm test                    # Run all tests
 *   npm run test:smoke         # Run smoke tests only
 *   npm run test:ui            # Run with Playwright UI
 *   npm run test:headed        # Run in headed mode
 */
module.exports = defineConfig({
  testDir: './specs',
  fullyParallel: true,
  forbidOnly: !!process.env.CI,
  retries: process.env.CI ? 2 : 0,
  workers: process.env.CI ? 1 : undefined,
  reporter: [
    ['html'],
    ['list'],
    ['json', { outputFile: 'test-results/results.json' }],
    ['junit', { outputFile: 'test-results/junit.xml' }]
  ],
  
  // Snapshot directory for visual regression
  snapshotPathTemplate: '{testDir}/__snapshots__/{testFilePath}/{arg}{ext}',
  use: {
    baseURL: 'http://localhost:4000',
    // Enhanced tracing: capture traces for all tests (not just failures)
    trace: process.env.CI ? 'on' : 'on-first-retry',
    // Screenshots: capture on failure and during test execution
    screenshot: process.env.CI ? 'on' : 'only-on-failure',
    // Videos: retain on failure, and in CI for all tests
    video: process.env.CI ? 'on' : 'retain-on-failure',
    actionTimeout: 10000,
    navigationTimeout: 30000,
  },
  
  // Visual regression testing configuration
  expect: {
    // Threshold for pixel comparison (0.2 = 20% difference allowed)
    toHaveScreenshot: {
      threshold: 0.2,
      mode: 'rgb',
      maxDiffPixels: 100,
    },
    // Snapshot comparison
    toMatchSnapshot: {
      threshold: 0.2,
    },
  },
  projects: [
    {
      name: 'chromium',
      use: { ...devices['Desktop Chrome'] },
    },
    {
      name: 'firefox',
      use: { ...devices['Desktop Firefox'] },
    },
    {
      name: 'webkit',
      use: { ...devices['Desktop Safari'] },
    },
  ],
  webServer: {
    command: 'echo "Please ensure Phoenix server is running on http://localhost:4000"',
    url: 'http://localhost:4000',
    reuseExistingServer: !process.env.CI,
    timeout: 120000,
  },
});

