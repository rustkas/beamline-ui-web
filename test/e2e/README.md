# UI-Web E2E Tests with Playwright

This directory contains end-to-end (E2E) tests for UI-Web using Playwright.

## Prerequisites

1. **Node.js** (v18+)
2. **Phoenix server** running on `http://localhost:4000`
3. **Mock Gateway** running on `http://localhost:8081`

## Setup

```bash
cd apps/ui_web/test/e2e
npm install
```

## Running Tests

### Run all tests
```bash
npm test
```

### Run smoke tests only
```bash
npm run test:smoke
```

### Run visual regression tests
```bash
npm run test:visual
```

### Update visual regression baselines
```bash
npm run test:visual:update
```

### Run with Playwright UI (recommended for development)
```bash
npm run test:ui
```

### Run in headed mode (see browser)
```bash
npm run test:headed
```

### Run in debug mode
```bash
npm run test:debug
```

### View test report
```bash
npm run report
```

## Test Structure

```
test/e2e/
├── specs/
│   ├── messages.smoke.spec.js    # Smoke tests for MessagesLive
│   └── ...                        # Additional test files
├── playwright.config.js           # Playwright configuration
├── package.json                   # Node dependencies
└── README.md                      # This file
```

## Smoke Tests

Smoke tests (`@smoke` tag) verify critical user flows without deep validation:

- ✅ Page loads and displays messages table
- ✅ Filter by status works
- ✅ Filter by type works
- ✅ Selection and bulk actions appear
- ✅ Pagination next/previous works
- ✅ Empty state displays when no messages
- ✅ Page does not crash on rapid interactions

## Visual Regression Tests

Visual regression tests capture screenshots and compare them against baseline images stored in `__snapshots__/`.

### Baseline Images

Baseline images are stored in:
```
test/e2e/__snapshots__/specs/messages.visual.spec.js/
  - messages-initial-view-expected.png
  - messages-filtered-view-expected.png
  - messages-bulk-actions-bar-expected.png
  - messages-empty-state-expected.png
  - messages-pagination-controls-expected.png
  - messages-error-flash-expected.png
  - messages-table-row-expected.png
  - messages-filter-dropdowns-expected.png
```

### Updating Baselines

When UI changes are intentional, update baselines:

```bash
npm run test:visual:update
```

This will:
1. Capture new screenshots
2. Replace baseline images
3. Commit the updated baselines to git

### Visual Test Configuration

Visual tests use:
- **Threshold**: 0.2 (20% pixel difference allowed)
- **Mode**: RGB color comparison
- **Max diff pixels**: 100 (for full page), 30-50 (for components)

Configuration is in `playwright.config.js`:
```javascript
expect: {
  toHaveScreenshot: {
    threshold: 0.2,
    mode: 'rgb',
    maxDiffPixels: 100,
  },
}
```

## CI Integration

In CI, tests run with:
- 2 retries on failure
- 1 worker (sequential)
- HTML and JSON reports

## Configuration

Edit `playwright.config.js` to:
- Change base URL
- Adjust timeouts
- Add/remove browsers
- Configure reporters

## Troubleshooting

### Tests fail with "Navigation timeout"
- Ensure Phoenix server is running: `mix phx.server`
- Check server is accessible: `curl http://localhost:4000`

### Tests fail with "Gateway error"
- Ensure Mock Gateway is running: `mix mock_gateway.start` (or your setup command)
- Check gateway is accessible: `curl http://localhost:8081/health`

### Authentication

E2E tests use `/dev-login` endpoint for authentication:

```javascript
test.beforeEach(async ({ page }) => {
  await page.goto('/dev-login?user=test_user&tenant=test_tenant');
  await page.waitForURL(/\/app\/dashboard/, { timeout: 10000 });
});
```

**Note:** `/dev-login` is only available in `test`/`dev` environments for security.

### Tests are flaky
- Increase timeouts in `playwright.config.js`
- Use `page.waitForSelector()` instead of `page.waitForTimeout()`
- Check for race conditions in test logic

## Best Practices

1. **Use data-testid attributes** in templates for reliable selectors
2. **Wait for elements** before interacting (use `waitForSelector`)
3. **Use meaningful test names** that describe the user flow
4. **Keep tests independent** - each test should be able to run alone
5. **Use @smoke tag** for critical paths that must always pass

## References

- [Playwright Documentation](https://playwright.dev/)
- [UI-Web Test Strategy](../docs/UI_WEB_TEST_STRATEGY.md)
- [MessagesLive Event Flows](../docs/MESSAGES_LIVE_EVENT_FLOWS.md)

