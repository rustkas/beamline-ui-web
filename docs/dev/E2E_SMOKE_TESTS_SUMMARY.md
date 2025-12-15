# E2E Smoke Tests - Implementation Summary

**Status:** ✅ **COMPLETE**

Minimal smoke test set for Dashboard, Messages, and Extensions has been implemented.

---

## ✅ What Was Implemented

### 1. Dev Login Endpoint

**File:** `apps/ui_web/lib/ui_web_web/controllers/dev_login_controller.ex`

**Purpose:** Simple authentication for E2E tests without requiring OIDC or real auth flow.

**Route:** `GET /dev-login?user=test_user&tenant=test_tenant`

**Security:**
- Only available in `test`/`dev` environments
- Never available in production

**Usage:**
```javascript
test.beforeEach(async ({ page }) => {
  await page.goto('/dev-login?user=test_user&tenant=test_tenant');
  await page.waitForURL(/\/app\/dashboard/, { timeout: 10000 });
});
```

---

### 2. Dashboard Smoke Tests

**File:** `apps/ui_web/test/e2e/specs/dashboard.smoke.spec.js`

**Scenarios:**
1. ✅ `Dashboard loads and shows core tiles`
   - Verifies page loads
   - Checks for core sections (System Status, Component Health, Real-time Metrics)
   - Verifies Gateway/Router/Workers sections

2. ✅ `Dashboard handles health error gracefully`
   - Tests error handling with `?health=force_error`
   - Verifies page doesn't crash
   - Ensures dashboard remains visible

3. ✅ `Dashboard polling updates (optional)`
   - Waits for polling cycle
   - Verifies page remains responsive

---

### 3. Messages Smoke Tests (Enhanced)

**File:** `apps/ui_web/test/e2e/specs/messages.smoke.spec.js`

**Existing scenarios:**
- ✅ Page loads and displays messages table
- ✅ Filter by status works
- ✅ Filter by type works
- ✅ Selection and bulk actions appear
- ✅ Pagination next/previous works
- ✅ Empty state displays when no messages
- ✅ Page does not crash on rapid interactions

**New scenarios:**
- ✅ `Messages show opens` - Navigate to message detail page
- ✅ `Bulk select works (without real delete)` - Verify bulk actions functionality

**Updated:**
- ✅ All tests now use `/dev-login` for authentication

---

### 4. Extensions Smoke Tests

**File:** `apps/ui_web/test/e2e/specs/extensions.smoke.spec.js`

**Scenarios:**
1. ✅ `Extensions index loads`
   - Verifies page loads
   - Checks for extensions table
   - Verifies extension IDs from mock data

2. ✅ `Filter by provider/type works`
   - Tests filtering functionality
   - Verifies table updates correctly

3. ✅ `Toggle extension enabled works`
   - Tests toggle functionality
   - Verifies state changes
   - Ensures no crashes

4. ✅ `Delete extension works (optional)`
   - Tests deletion flow
   - Verifies extension removed from table

---

## 📋 Test Coverage Summary

### Dashboard (3 tests)
- ✅ Core tiles loading
- ✅ Error handling
- ✅ Polling updates (optional)

### Messages (9 tests)
- ✅ Index loading
- ✅ Show page navigation
- ✅ Filtering (status, type)
- ✅ Selection and bulk actions
- ✅ Pagination
- ✅ Empty state
- ✅ Rapid interactions
- ✅ Bulk operations

### Extensions (4 tests)
- ✅ Index loading
- ✅ Filtering
- ✅ Toggle enabled
- ✅ Delete (optional)

**Total:** 16 smoke tests covering critical user flows

---

## 🔧 Configuration

### Router Update

**File:** `apps/ui_web/lib/ui_web_web/router.ex`

Added dev-login route:
```elixir
if Mix.env() in [:test, :dev] do
  get "/dev-login", DevLoginController, :login
end
```

### Playwright Config

**File:** `apps/ui_web/test/e2e/playwright.config.js`

- Base URL: `http://localhost:4000`
- Retries: 2 in CI, 0 locally
- Workers: 1 in CI, parallel locally
- Reports: HTML, JSON, JUnit

---

## 🚀 Running E2E Smoke Tests

### Prerequisites

1. **Phoenix server running:**
   ```bash
   cd apps/ui_web
   MIX_ENV=test mix phx.server
   ```

2. **Mock Gateway running:**
   - Auto-starts via `test_helper.exs`
   - Or verify: `curl http://localhost:8081/health`

### Commands

```bash
cd apps/ui_web/test/e2e

# Run all smoke tests
npm run test:smoke

# Run specific test file
npx playwright test specs/dashboard.smoke.spec.js
npx playwright test specs/messages.smoke.spec.js
npx playwright test specs/extensions.smoke.spec.js

# Run with UI (recommended for development)
npm run test:ui

# Run in headed mode
npm run test:headed
```

---

## 🔄 CI Integration

### Current Workflows

1. **Visual Regression** (`.github/workflows/ui-web-e2e-visual.yml`)
   - Runs visual regression tests
   - Includes smoke tests

2. **Matrix Tests** (`.github/workflows/ui-web-matrix-tests.yml`)
   - Runs E2E tests across browsers (Chromium, Firefox, WebKit)
   - Includes smoke tests

### Smoke Tests in CI

Smoke tests run automatically:
- On push to `main`/`develop`
- On pull requests
- Via `workflow_dispatch`

**CI Steps:**
1. Start Phoenix server (`MIX_ENV=test mix phx.server`)
2. Wait for server ready
3. Run Playwright tests (`npm test` or `npm run test:smoke`)
4. Upload HTML report and screenshots

---

## ✅ What E2E Smoke Set Provides

1. ✅ Confirms **key pages actually work in browser**
2. ✅ Catches:
   - Broken assets/JS
   - LiveSocket regressions
   - Routing errors
   - Auth integration issues
3. ✅ Gives confidence before release: if E2E smoke is green – at least Dashboard, Messages, and Extensions are alive and interactive

---

## 📚 Documentation

- **Strategy:** `apps/ui_web/docs/dev/E2E_TESTING_STRATEGY.md`
- **E2E README:** `apps/ui_web/test/e2e/README.md`
- **Dev Login:** `apps/ui_web/lib/ui_web_web/controllers/dev_login_controller.ex`

---

## 🎯 Next Steps (Optional)

### Future Enhancements

1. **Full E2E Tests** (beyond smoke)
   - Complete message creation flow
   - Complete extension management flow
   - Error scenarios with real browser interactions

2. **Cross-Browser Testing**
   - Already configured in matrix workflow
   - Can expand to more scenarios

3. **Performance Testing**
   - Measure page load times
   - Track rendering performance

4. **Accessibility Testing**
   - Add Playwright accessibility checks
   - Verify ARIA attributes

---

## Summary

**Status:** ✅ **COMPLETE**

All smoke tests implemented:
- ✅ Dev login endpoint created
- ✅ Dashboard smoke tests (3 scenarios)
- ✅ Messages smoke tests enhanced (9 scenarios)
- ✅ Extensions smoke tests (4 scenarios)
- ✅ CI integration ready
- ✅ Documentation complete

**Total:** 16 smoke tests covering critical user flows for Dashboard, Messages, and Extensions.

