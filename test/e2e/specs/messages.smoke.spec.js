// @ts-check
const { test, expect } = require('@playwright/test');

/**
 * Smoke E2E tests for MessagesLive.Index
 * 
 * These tests verify critical user flows without deep validation.
 * Run with: npm run test:smoke
 * 
 * @smoke
 */
test.describe('MessagesLive.Index Smoke Tests', () => {
  test.beforeEach(async ({ page }) => {
    // Authenticate via dev-login
    await page.goto('/dev-login?user=test_user&tenant=test_tenant');
    await page.waitForURL(/\/app\/dashboard/, { timeout: 10000 });
    
    // Navigate to messages page
    await page.goto('/app/messages');
    
    // Wait for initial load
    await page.waitForSelector('table, [data-testid="messages-table"]', { timeout: 10000 });
  });

  test('@smoke - page loads and displays messages table', async ({ page }) => {
    // Verify page title
    await expect(page).toHaveTitle(/Messages/i);
    
    // Verify table is visible
    const table = page.locator('table, [data-testid="messages-table"]').first();
    await expect(table).toBeVisible();
    
    // Verify at least one message row exists
    const rows = page.locator('tbody tr, [data-testid="message-row"]');
    await expect(rows.first()).toBeVisible({ timeout: 5000 });
  });

  test('@smoke - filter by status works', async ({ page }) => {
    // Find status filter
    const statusFilter = page.locator('select[name="status"]');
    await expect(statusFilter).toBeVisible();
    
    // Change filter to "completed"
    await statusFilter.selectOption('completed');
    
    // Wait for table update
    await page.waitForTimeout(1000);
    
    // Verify filter is applied (URL should change)
    await expect(page).toHaveURL(/status=completed/);
    
    // Verify table still visible
    const table = page.locator('table, [data-testid="messages-table"]').first();
    await expect(table).toBeVisible();
  });

  test('@smoke - filter by type works', async ({ page }) => {
    // Find type filter
    const typeFilter = page.locator('select[name="type"]');
    await expect(typeFilter).toBeVisible();
    
    // Change filter to "chat"
    await typeFilter.selectOption('chat');
    
    // Wait for table update
    await page.waitForTimeout(1000);
    
    // Verify filter is applied
    await expect(page).toHaveURL(/type=chat/);
    
    // Verify table still visible
    const table = page.locator('table, [data-testid="messages-table"]').first();
    await expect(table).toBeVisible();
  });

  test('@smoke - selection and bulk actions appear', async ({ page }) => {
    // Find first checkbox
    const firstCheckbox = page.locator('input[type="checkbox"][phx-click="toggle_select"]').first();
    await expect(firstCheckbox).toBeVisible({ timeout: 5000 });
    
    // Initially, bulk bar should not be visible
    const bulkBar = page.locator('[data-testid="bulk-actions"], .bulk-actions, [class*="bulk"]');
    const initialBulkCount = await bulkBar.count();
    
    // Click checkbox to select message
    await firstCheckbox.click();
    
    // Wait for bulk bar to appear
    await page.waitForTimeout(1000);
    
    // Verify bulk actions are visible
    const bulkText = page.locator('text=/message\\(s\\) selected/i, text=Delete Selected, text=Export JSON');
    const bulkTextCount = await bulkText.count();
    
    if (bulkTextCount > 0) {
      await expect(bulkText.first()).toBeVisible({ timeout: 2000 });
    } else {
      // Fallback: check that bulk bar appeared
      const bulkBarAfter = page.locator('[data-testid="bulk-actions"], .bulk-actions, [class*="bulk"]');
      const afterCount = await bulkBarAfter.count();
      expect(afterCount).toBeGreaterThan(initialBulkCount);
    }
  });
  
  test('@smoke - messages show opens', async ({ page }) => {
    // Wait for messages to load
    await page.waitForSelector('table, [data-testid="messages-table"]', { timeout: 10000 });
    
    // Find first message row or link
    const messageLink = page.locator(
      'a[href*="/app/messages/"], button[phx-click*="view"], text=/msg_\\d+/'
    ).first();
    
    const linkCount = await messageLink.count();
    
    if (linkCount > 0) {
      // Click on first message
      await messageLink.click();
      
      // Wait for navigation to show page
      await page.waitForURL(/\/app\/messages\/msg_\d+/, { timeout: 10000 });
      
      // Verify show page loaded
      await expect(page).toHaveURL(/\/app\/messages\/msg_\d+/);
      
      // Verify message content is visible
      const messageContent = page.locator('text=/msg_\\d+/, text=Message, [data-testid="message-content"]');
      await expect(messageContent.first()).toBeVisible({ timeout: 5000 });
    } else {
      // Skip if no message links available
      test.skip();
    }
  });
  
  test('@smoke - bulk select works (without real delete)', async ({ page }) => {
    // Wait for messages to load
    await page.waitForSelector('table, [data-testid="messages-table"]', { timeout: 10000 });
    
    // Find first checkbox
    const firstCheckbox = page.locator('input[type="checkbox"][phx-click="toggle_select"]').first();
    await expect(firstCheckbox).toBeVisible({ timeout: 5000 });
    
    // Click to select
    await firstCheckbox.click();
    
    // Wait for bulk bar
    await page.waitForTimeout(1000);
    
    // Verify bulk actions bar appeared
    const bulkBar = page.locator(
      'text=/message\\(s\\) selected/i, [data-testid="bulk-actions"], .bulk-actions'
    );
    await expect(bulkBar.first()).toBeVisible({ timeout: 2000 });
    
    // Verify Export JSON button exists
    const exportButton = page.locator('button:has-text("Export JSON"), button[phx-click="export"][phx-value-format="json"]');
    await expect(exportButton.first()).toBeVisible({ timeout: 2000 });
    
    // Verify Delete Selected button exists
    const deleteButton = page.locator('button:has-text("Delete Selected"), button[phx-click="bulk_delete"]');
    await expect(deleteButton.first()).toBeVisible({ timeout: 2000 });
    
    // Click Delete Selected (verify it doesn't crash, not checking actual deletion)
    await deleteButton.first().click();
    
    // Wait for response
    await page.waitForTimeout(2000);
    
    // Verify page is still responsive (no crash)
    await expect(page).toHaveURL(/\/app\/messages/);
    const table = page.locator('table, [data-testid="messages-table"]').first();
    await expect(table).toBeVisible();
  });

  test('@smoke - pagination next/previous works', async ({ page }) => {
    // Find pagination buttons
    const nextButton = page.locator('button[phx-click="next_page"], button:has-text("Next")');
    const prevButton = page.locator('button[phx-click="prev_page"], button:has-text("Previous")');
    
    // Check if pagination exists
    const hasPagination = await nextButton.count() > 0 || prevButton.count() > 0;
    
    if (hasPagination) {
      // Try clicking next if available
      if (await nextButton.count() > 0) {
        const initialUrl = page.url();
        await nextButton.first().click();
        
        // Wait for navigation
        await page.waitForTimeout(1000);
        
        // Verify URL or content changed
        const newUrl = page.url();
        expect(newUrl).not.toBe(initialUrl);
      }
      
      // Try clicking previous if available
      if (await prevButton.count() > 0) {
        const currentUrl = page.url();
        await prevButton.first().click();
        
        // Wait for navigation
        await page.waitForTimeout(1000);
        
        // Verify URL or content changed
        const finalUrl = page.url();
        expect(finalUrl).not.toBe(currentUrl);
      }
    } else {
      // Skip if no pagination (single page)
      test.skip();
    }
  });

  test('@smoke - empty state displays when no messages', async ({ page }) => {
    // Navigate with empty_test filter
    await page.goto('/app/messages?status=empty_test');
    
    // Wait for empty state
    await page.waitForTimeout(2000);
    
    // Verify empty state message appears
    const emptyState = page.locator(
      'text=No messages, text=No data, text=empty, [data-testid="empty-state"]'
    );
    
    // At least one empty state indicator should be visible
    const hasEmptyState = await emptyState.count() > 0;
    expect(hasEmptyState).toBeTruthy();
  });

  test('@smoke - page does not crash on rapid interactions', async ({ page }) => {
    // Rapid filter changes
    const statusFilter = page.locator('select[name="status"]');
    if (await statusFilter.count() > 0) {
      await statusFilter.selectOption('completed');
      await page.waitForTimeout(200);
      await statusFilter.selectOption('failed');
      await page.waitForTimeout(200);
      await statusFilter.selectOption('all');
      await page.waitForTimeout(1000);
      
      // Verify page is still responsive
      const table = page.locator('table, [data-testid="messages-table"]').first();
      await expect(table).toBeVisible();
    }
    
    // Rapid checkbox clicks
    const checkboxes = page.locator('input[type="checkbox"][phx-click="toggle_select"]');
    if (await checkboxes.count() > 0) {
      await checkboxes.first().click();
      await page.waitForTimeout(100);
      await checkboxes.first().click();
      await page.waitForTimeout(100);
      
      // Verify page is still responsive
      await expect(page).toHaveURL(/\/app\/messages/);
    }
  });
});

