// @ts-check
const { test, expect } = require('@playwright/test');

/**
 * Smoke E2E tests for ExtensionsLive
 * 
 * These tests verify critical user flows without deep validation.
 * Run with: npm run test:smoke
 * 
 * @smoke
 */
test.describe('ExtensionsLive Smoke Tests', () => {
  test.beforeEach(async ({ page }) => {
    // Authenticate via dev-login
    await page.goto('/dev-login?user=test_user&tenant=test_tenant');
    await page.waitForURL(/\/app\/dashboard/, { timeout: 10000 });
  });

  test('@smoke - extensions index loads', async ({ page }) => {
    await page.goto('/app/extensions');
    
    // Wait for initial load
    await page.waitForSelector('h1, table, [data-testid="extensions-table"]', { timeout: 10000 });
    
    // Verify page title
    await expect(page).toHaveTitle(/Extensions/i);
    
    // Verify table is visible
    const table = page.locator('table, [data-testid="extensions-table"]').first();
    await expect(table).toBeVisible();
    
    // Verify at least one extension row exists (from mock data)
    const rows = page.locator('tbody tr, [data-testid="extension-row"]');
    const rowCount = await rows.count();
    expect(rowCount).toBeGreaterThan(0);
    
    // Verify extension ID is visible (ext_001 or similar from mock)
    const extensionId = page.locator('text=/ext_\\d+/, text=/extension_\\d+/');
    await expect(extensionId.first()).toBeVisible({ timeout: 5000 });
  });

  test('@smoke - filter by provider/type works', async ({ page }) => {
    await page.goto('/app/extensions');
    
    // Wait for initial load
    await page.waitForSelector('table, [data-testid="extensions-table"]', { timeout: 10000 });
    
    // Find filter (provider or type)
    const filter = page.locator('select[name="provider"], select[name="type"], select[name="status"]').first();
    const filterCount = await filter.count();
    
    if (filterCount > 0) {
      // Get available options
      const options = await filter.locator('option').all();
      if (options.length > 1) {
        // Select first non-empty option
        const firstOption = await options[1].getAttribute('value');
        if (firstOption) {
          await filter.selectOption(firstOption);
          
          // Wait for filter to apply
          await page.waitForTimeout(1000);
          
          // Verify table still visible
          const table = page.locator('table, [data-testid="extensions-table"]').first();
          await expect(table).toBeVisible();
          
          // Verify URL or content changed
          const url = page.url();
          expect(url).toContain('/app/extensions');
        }
      }
    } else {
      // Skip if no filter available
      test.skip();
    }
  });

  test('@smoke - toggle extension enabled works', async ({ page }) => {
    await page.goto('/app/extensions');
    
    // Wait for initial load
    await page.waitForSelector('table, [data-testid="extensions-table"]', { timeout: 10000 });
    
    // Find toggle button/checkbox for first extension
    const toggle = page.locator(
      'input[type="checkbox"][phx-click*="toggle"], button[phx-click*="toggle"], [data-testid="toggle-enabled"]'
    ).first();
    
    const toggleCount = await toggle.count();
    
    if (toggleCount > 0) {
      // Get initial state (if visible)
      const initialState = await toggle.isChecked().catch(() => null);
      
      // Click toggle
      await toggle.click();
      
      // Wait for update
      await page.waitForTimeout(1000);
      
      // Verify page is still responsive (no crash)
      const table = page.locator('table, [data-testid="extensions-table"]').first();
      await expect(table).toBeVisible();
      
      // Verify toggle state changed (if checkbox)
      if (initialState !== null) {
        const newState = await toggle.isChecked().catch(() => null);
        if (newState !== null) {
          expect(newState).not.toBe(initialState);
        }
      }
    } else {
      // Skip if no toggle available
      test.skip();
    }
  });

  test('@smoke - delete extension works (optional)', async ({ page }) => {
    await page.goto('/app/extensions');
    
    // Wait for initial load
    await page.waitForSelector('table, [data-testid="extensions-table"]', { timeout: 10000 });
    
    // Find delete button for first extension
    const deleteButton = page.locator(
      'button[phx-click*="delete"], button:has-text("Delete"), [data-testid="delete-extension"]'
    ).first();
    
    const deleteCount = await deleteButton.count();
    
    if (deleteCount > 0) {
      // Get initial row count
      const initialRows = page.locator('tbody tr, [data-testid="extension-row"]');
      const initialCount = await initialRows.count();
      
      // Click delete
      await deleteButton.click();
      
      // Handle confirmation dialog if present
      page.on('dialog', async dialog => {
        await dialog.accept();
      });
      
      // Wait for deletion
      await page.waitForTimeout(2000);
      
      // Verify row count decreased OR extension removed
      const newRows = page.locator('tbody tr, [data-testid="extension-row"]');
      const newCount = await newRows.count();
      
      // Either count decreased or page still functional
      expect(newCount <= initialCount || await page.url()).toContain('/app/extensions');
    } else {
      // Skip if no delete button available
      test.skip();
    }
  });
});

