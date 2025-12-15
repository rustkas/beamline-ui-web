# E2E HTML Report

**Status:** ✅ **COMPLETE**

Enhanced HTML reporting for E2E tests with videos, screenshots, and traces for comprehensive debugging.

---

## 🎯 Purpose

The E2E HTML Report provides:
- **Interactive test results** - Visual timeline and execution details
- **Video recordings** - Watch test execution in real-time
- **Step-by-step screenshots** - Visual progression of each test step
- **Trace viewer** - Interactive debugging with DOM snapshots and network logs
- **Failure analysis** - Detailed error messages and stack traces

---

## 📋 Features

### HTML Report Contents

1. **Test Summary:**
   - Total tests, passed, failed, skipped
   - Execution time
   - Test timeline

2. **Test Details:**
   - Step-by-step execution log
   - Screenshots for each step
   - Video playback (on failure or in CI)
   - Trace viewer for debugging

3. **Failure Analysis:**
   - Error messages and stack traces
   - Screenshot at failure point
   - Video recording of failed test
   - Trace file for interactive debugging

4. **Visual Regression:**
   - Baseline vs actual screenshots
   - Pixel diff visualization
   - Threshold indicators

---

## 🚀 Usage

### Generate HTML Report

**Automatically (in CI):**
- HTML report is generated after each test run
- Uploaded as artifact: `playwright-html-report`

**Locally:**
```bash
cd apps/ui_web/test/e2e
npm test
npm run report  # Opens HTML report in browser
```

### View HTML Report

**From CI Artifact:**
1. Download `playwright-html-report` artifact from GitHub Actions
2. Extract archive
3. Open `index.html` in browser

**Locally:**
```bash
cd apps/ui_web/test/e2e
npx playwright show-report
```

---

## 📊 Report Configuration

### Playwright Config

**File:** `apps/ui_web/test/e2e/playwright.config.js`

**Reporters:**
```javascript
reporter: [
  ['html'],  // HTML report
  ['list'],  // Console output
  ['json', { outputFile: 'test-results/results.json' }],
  ['junit', { outputFile: 'test-results/junit.xml' }]
]
```

**Enhanced Tracing (CI):**
```javascript
use: {
  // Capture traces for all tests in CI
  trace: process.env.CI ? 'on' : 'on-first-retry',
  // Capture screenshots during test execution
  screenshot: process.env.CI ? 'on' : 'only-on-failure',
  // Record videos for all tests in CI
  video: process.env.CI ? 'on' : 'retain-on-failure',
}
```

---

## 🎥 Video Recordings

### When Videos Are Recorded

- **CI:** All tests (for comprehensive debugging)
- **Local:** Only on failure (to save disk space)

### Video Format

- **Format:** MP4 (H.264)
- **Location:** `test-results/<test-name>/video.webm` (converted to MP4)
- **Retention:** 90 days in CI artifacts

### Viewing Videos

**In HTML Report:**
- Click on failed test
- Scroll to "Video" section
- Click play button

**Direct Access:**
```bash
# Videos are in test-results directory
ls apps/ui_web/test/e2e/test-results/*/video.webm
```

---

## 📸 Screenshots

### When Screenshots Are Captured

- **CI:** During test execution (for all steps)
- **Local:** Only on failure (to save disk space)

### Screenshot Types

1. **Step Screenshots:**
   - Captured after each action (click, type, navigate)
   - Shows UI state at each step

2. **Failure Screenshots:**
   - Captured at the moment of failure
   - Highlights the element that caused failure

3. **Visual Regression Screenshots:**
   - Baseline vs actual comparison
   - Pixel diff visualization

### Screenshot Format

- **Format:** PNG
- **Location:** `test-results/<test-name>/screenshots/`
- **Retention:** 90 days in CI artifacts

---

## 🔍 Trace Viewer

### What Is a Trace?

A trace is an interactive recording of test execution that includes:
- **DOM Snapshots** - Full page state at each step
- **Network Logs** - All HTTP requests and responses
- **Console Logs** - JavaScript console output
- **Source Code** - Test code with execution highlights

### When Traces Are Captured

- **CI:** All tests (for comprehensive debugging)
- **Local:** Only on first retry (to save disk space)

### Viewing Traces

**In HTML Report:**
1. Click on test
2. Scroll to "Trace" section
3. Click "Open trace" button
4. Interactive trace viewer opens in new tab

**Direct Access:**
```bash
# Traces are in test-results directory
ls apps/ui_web/test/e2e/test-results/*/trace.zip

# Open trace viewer
npx playwright show-trace test-results/<test-name>/trace.zip
```

### Trace Viewer Features

- **Timeline** - Visual timeline of test execution
- **DOM Explorer** - Inspect DOM at any point
- **Network Inspector** - View all network requests
- **Console Logs** - Filter and search console output
- **Source Code** - Step through test code

---

## 📦 Artifacts in CI

### GitHub Actions Artifacts

**Artifact:** `playwright-html-report`
- **Contents:** Complete HTML report with all test results
- **Retention:** 30 days (nightly: 90 days)

**Artifact:** `visual-test-results` / `nightly-e2e-test-results`
- **Contents:** Test results JSON, JUnit XML
- **Retention:** 30 days (nightly: 90 days)

**Artifact:** `visual-test-screenshots` / `nightly-e2e-media`
- **Contents:** Videos (`.mp4`), Screenshots (`.png`)
- **Retention:** 30 days (nightly: 90 days)

**Artifact:** `nightly-e2e-traces`
- **Contents:** Trace files (`.zip`)
- **Retention:** 90 days

---

## 🔧 Configuration

### Enable Full Tracing Locally

```bash
# Set environment variable
export CI=true

# Or in Playwright config
trace: 'on'  # Always capture traces
```

### Customize Screenshot Capture

```javascript
// In test file
test('my test', async ({ page }) => {
  // Capture screenshot at specific point
  await page.screenshot({ path: 'custom-screenshot.png' });
});
```

### Customize Video Recording

```javascript
// In test file
test.use({
  video: 'on',  // Always record video
});
```

---

## 📚 Files

### Configuration

- **`apps/ui_web/test/e2e/playwright.config.js`** - Playwright configuration
- **`.github/workflows/ui-web-e2e-visual.yml`** - CI workflow with artifact upload
- **`.github/workflows/ui-web-nightly-e2e.yml`** - Nightly workflow with enhanced artifacts

### Generated Files

- **`apps/ui_web/test/e2e/playwright-report/`** - HTML report directory
- **`apps/ui_web/test/e2e/test-results/`** - Test results, videos, screenshots, traces

---

## ✅ Acceptance Criteria

1. ✅ HTML report generated after each test run
2. ✅ Videos recorded for all tests in CI, on failure locally
3. ✅ Screenshots captured during test execution
4. ✅ Traces captured for all tests in CI, on retry locally
5. ✅ Artifacts uploaded to GitHub Actions
6. ✅ Report accessible via browser
7. ✅ Trace viewer interactive and functional
8. ✅ Documentation complete

---

## 🚀 Next Steps (Optional)

### Enhanced Features

1. **Custom Report Themes:**
   - Branded report styling
   - Custom logo and colors
   - Company-specific branding

2. **Report Analytics:**
   - Test execution trends
   - Failure rate analysis
   - Performance metrics

3. **Integration with Test Management:**
   - Export to TestRail, Jira
   - Link test results to issues
   - Track test coverage

4. **Automated Report Sharing:**
   - Email reports on failure
   - Slack notifications with report links
   - Dashboard integration

---

## 📖 References

- **Playwright HTML Report:** https://playwright.dev/docs/test-reporters#html-reporter
- **Trace Viewer:** https://playwright.dev/docs/trace-viewer
- **Screenshots:** https://playwright.dev/docs/screenshots
- **Videos:** https://playwright.dev/docs/videos

