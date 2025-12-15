# E2E Testing Strategy

**Goal:** Verify that key screens work in a real browser for actual users.

---

## Why E2E When LiveView Tests Exist?

### Current Coverage

- ✅ **LiveView tests** → Check UI logic at BE level (assigns, events, HTML)
- ✅ **Mock Gateway + client layer** → Covered by contract/unit/integration tests

### What's Missing

- ❌ Real browser rendering
- ❌ Verification that JS/HTML/CSS compile and actually work in browser
- ❌ Routing, assets, LiveSocket, hooks are not broken

### E2E Smoke Set Purpose

**Answer the question:**
> "If I deployed a new build – are key screens (Dashboard, Messages, Extensions) alive for real users in browser?"

---

## Tool Choice: Playwright vs Wallaby

### 🔹 Playwright (Current Choice)

**Pros:**
- ✅ Modern E2E standard
- ✅ Excellent UX: traces, screenshots, video
- ✅ Parallelism, stability
- ✅ Easy to run in CI (GitHub/GitLab)

**Cons:**
- ❌ Separate stack (Node/TS)
- ❌ Another language/toolchain

### 🔹 Wallaby (Elixir Alternative)

**Pros:**
- ✅ One language (Elixir)
- ✅ Tight integration with Phoenix
- ✅ Can use same helpers, config, sandbox

**Cons:**
- ❌ Less rich DX than Playwright
- ❌ Worse tooling around video/trace

**Decision:** We use **Playwright** for maximum power and modern E2E layer.

---

## E2E Environment Setup

### 1. Separate Environment Configuration

**Phoenix runs in:**
- `MIX_ENV=test` (for E2E tests)
- Uses **mock gateway** and **test DB** (if applicable)

### 2. Application Startup

**In CI:**
```bash
# Start Phoenix server in background
MIX_ENV=test mix phx.server &
# Wait for server to be ready
sleep 5
# Run Playwright tests
npm test
```

**Locally:**
```bash
# Option 1: Run server manually
MIX_ENV=test mix phx.server

# Option 2: Use Playwright webServer (configured in playwright.config.js)
npm test
```

### 3. Data

- Use same **mock data** as in tests (Messages, Extensions, Policies)
- Or minimal seed data in DB (for Dashboard)

### 4. Authentication

**Simple path: `/dev-login` endpoint**

- Sets required session/cookie
- Returns token for E2E test to use
- Example: `/dev-login?user=test_user&tenant=test_tenant`

**Implementation:**
- `apps/ui_web/lib/ui_web_web/controllers/dev_login_controller.ex`
- Only available in `test`/`dev` environments

---

## Minimal Smoke Test Set

### 4.1. Dashboard (Smoke)

**Goal:** Ensure general dashboard opens and shows health/metrics.

**Scenarios:**

1. **`Dashboard loads and shows core tiles`**
   - Open `/app/dashboard`
   - Verify:
     - Title `Dashboard`/`System status`
     - Visible blocks: Gateway, Router, Workers, NATS metrics
     - Status `OK` or expected stubs

2. **`Dashboard handles health error gracefully`**
   - Enable `force_error` mode via query or config
   - Open `/app/dashboard?health=force_error`
   - Verify:
     - Page doesn't crash (200, HTML renders)
     - Warning/error is displayed
     - No JS crash

3. **`Dashboard polling updates` (optional)**
   - Wait 1-2 polling cycles (by waiting for text/metric change)
   - Verify numbers or status updated

**File:** `test/e2e/specs/dashboard.smoke.spec.js`

---

### 4.2. Messages (Smoke)

**Goal:** Basic navigation and key actions.

**Scenarios:**

1. **`Messages index loads`**
   - Open `/app/messages`
   - Verify:
     - Title `Messages`
     - Table with messages
     - ID `msg_001` (from mock) is visible

2. **`Messages show opens`**
   - On `/app/messages` click first row or `View` link/id
   - Navigate to `/app/messages/msg_001`
   - Verify:
     - Title `Message` / `msg_001`
     - Message content is displayed

3. **`Messages filter works (happy path)`**
   - On `/app/messages` change filter (e.g., Status = `completed`)
   - Verify:
     - List updated
     - At least one `completed` present
     - `pending` disappeared/decreased

4. **`Messages bulk select works (without real delete)`**
   - Select checkbox for `msg_001`
   - Verify:
     - Panel "Bulk actions" / "message(s) selected" appeared
     - Buttons `Export JSON`, `Delete Selected` visible
   - Click `Delete Selected`:
     - Either verify **doesn't lead to error** (page alive)
     - Or, if mock allows, verify `msg_001` disappeared

**File:** `test/e2e/specs/messages.smoke.spec.js`

---

### 4.3. Extensions (Smoke)

**Goal:** List, filtering, toggle.

**Scenarios:**

1. **`Extensions index loads`**
   - Open `/app/extensions`
   - Verify:
     - Title `Extensions`
     - Table with extensions
     - `ext_001` / `extension_1` is displayed

2. **`Filter by provider/type`**
   - Select type = `openai`/`anthropic` (or equivalent)
   - Verify:
     - Table shows only matching extensions
     - At least one name matches mock data

3. **`Toggle extension enabled`**
   - Find row `ext_001`
   - Press toggle (button/checkbox)
   - Verify:
     - State (enabled/disabled) visually changed (class/icon/text)
     - No errors/crashes occurred

4. **`Delete extension` (optional)**
   - Press Delete on `ext_002`
   - Confirm (if confirm exists)
   - Verify:
     - `ext_002` disappeared from table

**File:** `test/e2e/specs/extensions.smoke.spec.js`

---

## Playwright Implementation

### Structure

```
apps/ui_web/test/e2e/
├── playwright.config.js
├── package.json
├── specs/
│   ├── dashboard.smoke.spec.js
│   ├── messages.smoke.spec.js
│   ├── extensions.smoke.spec.js
│   └── messages.visual.spec.js (visual regression)
└── README.md
```

### Example Test

```javascript
const { test, expect } = require('@playwright/test');

test.describe('Messages smoke', () => {
  test.beforeEach(async ({ page }) => {
    // dev-login
    await page.goto('/dev-login?user=test_user&tenant=test_tenant');
    await page.waitForURL(/\/app\/dashboard/, { timeout: 10000 });
  });

  test('messages index loads', async ({ page }) => {
    await page.goto('/app/messages');
    await expect(page.getByText('Messages')).toBeVisible();
    await expect(page.getByText('msg_001')).toBeVisible();
  });
});
```

---

## CI Integration

### GitHub Actions

```yaml
e2e:
  runs-on: ubuntu-latest
  steps:
    - uses: actions/checkout@v3
    - uses: actions/setup-node@v3
      with:
        node-version: '18'
    - uses: erlef/setup-beam@v1
      with:
        elixir-version: '1.15'
        otp-version: '26'
    
    - name: Install dependencies
      run: |
        cd apps/ui_web
        mix deps.get
        cd test/e2e && npm install
    
    - name: Start Phoenix server
      run: |
        cd apps/ui_web
        MIX_ENV=test mix phx.server &
        sleep 10
    
    - name: Run E2E tests
      run: |
        cd apps/ui_web/test/e2e
        npm test
    
    - name: Upload Playwright report
      if: always()
      uses: actions/upload-artifact@v3
      with:
        name: playwright-report
        path: apps/ui_web/test/e2e/playwright-report/
```

### GitLab CI

```yaml
e2e:
  stage: test
  image: elixir:1.15
  services:
    - name: node:18
  before_script:
    - cd apps/ui_web
    - mix deps.get
    - cd test/e2e && npm install
  script:
    - cd ../..
    - MIX_ENV=test mix phx.server &
    - sleep 10
    - cd apps/ui_web/test/e2e
    - npm test
  artifacts:
    when: always
    paths:
      - apps/ui_web/test/e2e/playwright-report/
```

---

## What E2E Smoke Set Provides

1. ✅ Confirms **key pages actually work in browser**
2. ✅ Catches:
   - Broken assets/JS
   - LiveSocket regressions
   - Routing errors
   - Auth integration issues
3. ✅ Gives confidence before release: if E2E smoke is green – at least Dashboard, Messages, and Extensions are alive and interactive

---

## Running E2E Tests

### Prerequisites

1. **Phoenix server running:**
   ```bash
   cd apps/ui_web
   MIX_ENV=test mix phx.server
   ```

2. **Mock Gateway running:**
   ```bash
   # Should auto-start via test_helper.exs
   # Or manually: check http://localhost:8081/health
   ```

### Commands

```bash
cd apps/ui_web/test/e2e

# Install dependencies (first time)
npm install

# Run all smoke tests
npm run test:smoke

# Run all tests
npm test

# Run with UI
npm run test:ui

# Run in headed mode
npm run test:headed

# Run specific test file
npx playwright test specs/dashboard.smoke.spec.js
```

---

## Test Organization

### Smoke Tests (Critical Paths)

- `dashboard.smoke.spec.js` - Dashboard loading and core functionality
- `messages.smoke.spec.js` - Messages CRUD and filtering
- `extensions.smoke.spec.js` - Extensions list and toggle

### Visual Regression Tests

- `messages.visual.spec.js` - Visual snapshots of Messages UI states

### Future: Full E2E Tests

- `messages.full.spec.js` - Complete message flows
- `extensions.full.spec.js` - Complete extension management

---

## Authentication in E2E

### Dev Login Endpoint

**Route:** `GET /dev-login?user=test_user&tenant=test_tenant`

**What it does:**
1. Creates test user with provided params
2. Signs in via Guardian
3. Redirects to `/app/dashboard`

**Security:**
- Only enabled in `test`/`dev` environments
- Never available in production

**Usage in tests:**
```javascript
test.beforeEach(async ({ page }) => {
  await page.goto('/dev-login?user=test_user&tenant=test_tenant');
  await page.waitForURL(/\/app\/dashboard/, { timeout: 10000 });
});
```

---

## Best Practices

### 1. Use Explicit Waits

```javascript
// ✅ Good
await page.waitForSelector('table', { timeout: 10000 });
await expect(page.getByText('Messages')).toBeVisible();

// ❌ Bad
await page.waitForTimeout(5000); // Fixed wait
```

### 2. Handle Optional Elements

```javascript
// ✅ Good
const toggle = page.locator('button[phx-click*="toggle"]').first();
const count = await toggle.count();
if (count > 0) {
  await toggle.click();
} else {
  test.skip();
}
```

### 3. Verify Page Doesn't Crash

```javascript
// ✅ Good
await expect(page).toHaveURL(/\/app\/messages/);
const content = await page.content();
expect(content.length).toBeGreaterThan(0);
```

### 4. Use Retries for Flaky Tests

```javascript
// Configure in playwright.config.js
retries: process.env.CI ? 2 : 0
```

---

## Troubleshooting

### Server Not Running

**Error:** `net::ERR_CONNECTION_REFUSED`

**Solution:**
```bash
cd apps/ui_web
MIX_ENV=test mix phx.server
```

### Authentication Fails

**Error:** Redirected to `/login` instead of dashboard

**Solution:**
- Check `/dev-login` route is available
- Verify `Mix.env() == :test` or `dev_login_enabled` config

### Mock Gateway Not Available

**Error:** Tests fail with gateway errors

**Solution:**
- Check Mock Gateway is running on `http://localhost:8081`
- Verify `test_helper.exs` starts Mock Gateway

---

## References

- Playwright Documentation: https://playwright.dev
- Test files: `apps/ui_web/test/e2e/specs/`
- Config: `apps/ui_web/test/e2e/playwright.config.js`
- Dev Login: `apps/ui_web/lib/ui_web_web/controllers/dev_login_controller.ex`

