# Nightly E2E Suite

**Status:** ✅ **COMPLETE**

Comprehensive nightly E2E test suite that runs full UI flow tests, visual regression, and accessibility checks across all browsers.

---

## 🎯 Purpose

The Nightly E2E Suite provides:
- **Full UI flow coverage** - All critical user journeys
- **Visual regression testing** - Screenshot comparison across browsers
- **Accessibility testing** - WCAG compliance checks
- **Cross-browser testing** - Chromium, Firefox, WebKit
- **Comprehensive reporting** - HTML reports with videos, screenshots, traces

---

## 📋 Features

### Test Coverage

1. **Smoke Tests:**
   - Dashboard loading and core tiles
   - Messages list, filtering, selection, pagination
   - Extensions registry, toggle, delete

2. **Visual Regression:**
   - Screenshot comparison against baselines
   - Pixel-level diff detection
   - Multi-browser baseline support

3. **Accessibility:**
   - WCAG compliance checks (if enabled)
   - Keyboard navigation
   - Screen reader compatibility

4. **Cross-Browser:**
   - Chromium (Chrome/Edge)
   - Firefox
   - WebKit (Safari)

---

## 🚀 Usage

### Manual Trigger

```bash
# Trigger via GitHub Actions UI
# Or via GitHub CLI:
gh workflow run ui-web-nightly-e2e.yml
```

### Scheduled Runs

The workflow runs automatically at **2 AM UTC daily**.

### Update Snapshots

```bash
# Trigger with snapshot update
gh workflow run ui-web-nightly-e2e.yml -f update_snapshots=true
```

### Disable Accessibility Tests

```bash
# Trigger without accessibility tests
gh workflow run ui-web-nightly-e2e.yml -f run_accessibility=false
```

---

## 📊 Workflow Configuration

### Schedule

```yaml
schedule:
  - cron: '0 2 * * *'  # 2 AM UTC daily
```

### Timeout

- **60 minutes** - Sufficient for full test suite across all browsers

### Artifacts Retention

- **90 days** - All artifacts (HTML reports, videos, screenshots, traces) retained for 90 days

---

## 📦 Artifacts

### HTML Report

**Artifact:** `nightly-e2e-html-report`

**Contains:**
- Test results summary
- Step-by-step screenshots
- Video recordings (on failure)
- Trace viewer for debugging
- Test timeline and execution details

**Usage:**
1. Download artifact from GitHub Actions
2. Extract `playwright-report/` directory
3. Open `index.html` in browser

### Test Results

**Artifact:** `nightly-e2e-test-results`

**Contains:**
- JSON test results
- JUnit XML reports
- Test metadata

### Media Files

**Artifact:** `nightly-e2e-media`

**Contains:**
- Video recordings (`.mp4`)
- Screenshots (`.png`)
- Visual regression diffs

### Traces

**Artifact:** `nightly-e2e-traces`

**Contains:**
- Playwright trace files (`.zip`)
- Interactive trace viewer data

---

## 🔧 Configuration

### Playwright Config

**File:** `apps/ui_web/test/e2e/playwright.config.js`

**Enhanced for CI:**
```javascript
use: {
  // Enhanced tracing: capture traces for all tests in CI
  trace: process.env.CI ? 'on' : 'on-first-retry',
  // Screenshots: capture on failure and during test execution
  screenshot: process.env.CI ? 'on' : 'only-on-failure',
  // Videos: retain on failure, and in CI for all tests
  video: process.env.CI ? 'on' : 'retain-on-failure',
}
```

### Environment Variables

| Variable | Default | Description |
|----------|---------|-------------|
| `NODE_ENV` | `test` | Node.js environment |
| `MIX_ENV` | `test` | Elixir environment |
| `UPDATE_SNAPSHOTS` | `false` | Update baseline snapshots |
| `run_accessibility` | `true` | Run accessibility tests |

---

## 📈 Test Execution

### Test Phases

1. **Setup:**
   - Checkout code
   - Install Node.js and Elixir dependencies
   - Cache Playwright browsers and Mix dependencies

2. **Server Startup:**
   - Start Phoenix server on port 4000
   - Start Mock Gateway on port 8081
   - Verify services are running

3. **Test Execution:**
   - Run full E2E test suite (smoke + visual)
   - Run accessibility tests (if enabled)
   - Execute across all browsers (Chromium, Firefox, WebKit)

4. **Artifact Collection:**
   - Upload HTML report
   - Upload test results
   - Upload videos and screenshots
   - Upload traces

5. **Report Generation:**
   - Generate GitHub Actions step summary
   - Include links to artifacts
   - Report test coverage

---

## 🔍 Debugging Failed Tests

### 1. Download HTML Report

```bash
# Download artifact from GitHub Actions
gh run download <run-id> -n nightly-e2e-html-report
```

### 2. View HTML Report

```bash
cd playwright-report
open index.html  # macOS
xdg-open index.html  # Linux
start index.html  # Windows
```

### 3. Analyze Failures

**HTML Report Features:**
- **Test Timeline** - See execution order and timing
- **Step-by-Step Screenshots** - Visual progression of each test
- **Video Playback** - Watch test execution
- **Trace Viewer** - Interactive debugging with DOM snapshots

### 4. Update Baselines

```bash
# If visual regression failures are expected
gh workflow run ui-web-nightly-e2e.yml -f update_snapshots=true
```

---

## 📚 Files

### Workflow

- **`.github/workflows/ui-web-nightly-e2e.yml`** - Nightly E2E workflow

### Configuration

- **`apps/ui_web/test/e2e/playwright.config.js`** - Playwright configuration
- **`apps/ui_web/test/e2e/package.json`** - NPM dependencies

### Test Specs

- **`apps/ui_web/test/e2e/specs/dashboard.smoke.spec.js`** - Dashboard smoke tests
- **`apps/ui_web/test/e2e/specs/messages.smoke.spec.js`** - Messages smoke tests
- **`apps/ui_web/test/e2e/specs/extensions.smoke.spec.js`** - Extensions smoke tests
- **`apps/ui_web/test/e2e/specs/messages.visual.spec.js`** - Visual regression tests

---

## ✅ Acceptance Criteria

1. ✅ Workflow runs nightly at 2 AM UTC
2. ✅ Full E2E test suite executes (smoke + visual)
3. ✅ Cross-browser testing (Chromium, Firefox, WebKit)
4. ✅ Accessibility tests run (if enabled)
5. ✅ HTML reports generated with videos, screenshots, traces
6. ✅ Artifacts retained for 90 days
7. ✅ GitHub Actions step summary includes test results
8. ✅ Documentation complete

---

## 🚀 Next Steps (Optional)

### Enhanced Features

1. **Performance Testing:**
   - Add performance benchmarks
   - Track page load times
   - Monitor resource usage

2. **Accessibility Automation:**
   - Integrate axe-core for automated checks
   - Generate accessibility reports
   - Track WCAG compliance over time

3. **Test Parallelization:**
   - Run tests in parallel across browsers
   - Reduce execution time
   - Optimize resource usage

4. **Slack/Email Notifications:**
   - Send notifications on failures
   - Include test summary and links to artifacts
   - Track test trends over time

---

## 📖 References

- **E2E Testing Strategy:** `apps/ui_web/docs/dev/E2E_TESTING_STRATEGY.md`
- **Visual Regression:** `apps/ui_web/test/e2e/specs/messages.visual.spec.js`
- **Playwright Documentation:** https://playwright.dev

