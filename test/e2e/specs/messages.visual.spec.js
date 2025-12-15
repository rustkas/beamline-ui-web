// @ts-check
const { test, expect } = require('@playwright/test');

/**
 * Visual regression tests for MessagesLive.Index
 * 
 * These tests capture screenshots and compare them against baseline images.
 * Run with: npm test -- messages.visual
 * 
 * To update baselines: npm test -- messages.visual --update-snapshots
 */
test.describe('MessagesLive.Index Visual Regression', () => {
  test.beforeEach(async ({ page }) => {
    // Navigate to messages page
    await page.goto('/app/messages');
    
    // Wait for initial load
    await page.waitForSelector('table, [data-testid="messages-table"]', { timeout: 10000 });
    
    // Wait for any animations/transitions to complete
    await page.waitForTimeout(500);
  });

  test('baseline - initial messages table view', async ({ page }) => {
    // Capture full page screenshot
    await expect(page).toHaveScreenshot('messages-initial-view.png', {
      fullPage: true,
      maxDiffPixels: 100,
    });
  });

  test('baseline - messages table with filters', async ({ page }) => {
    // Set up filters
    const statusFilter = page.locator('select[name="status"]');
    const typeFilter = page.locator('select[name="type"]');
    
    if (await statusFilter.count() > 0) {
      await statusFilter.selectOption('completed');
      await page.waitForTimeout(500);
    }
    
    if (await typeFilter.count() > 0) {
      await typeFilter.selectOption('chat');
      await page.waitForTimeout(500);
    }
    
    // Capture filtered view
    await expect(page).toHaveScreenshot('messages-filtered-view.png', {
      fullPage: true,
      maxDiffPixels: 100,
    });
  });

  test('baseline - bulk actions bar visible', async ({ page }) => {
    // Select a message
    const firstCheckbox = page.locator('input[type="checkbox"][phx-click="toggle_select"]').first();
    if (await firstCheckbox.count() > 0) {
      await firstCheckbox.click();
      await page.waitForTimeout(500);
    }
    
    // Capture bulk actions bar
    const bulkBar = page.locator('[data-testid="bulk-actions"], .bulk-actions, [class*="bulk"]').first();
    if (await bulkBar.count() > 0) {
      await expect(bulkBar).toHaveScreenshot('messages-bulk-actions-bar.png', {
        maxDiffPixels: 50,
      });
    } else {
      // Fallback: capture area where bulk bar should appear
      await expect(page.locator('body')).toHaveScreenshot('messages-bulk-actions-area.png', {
        maxDiffPixels: 100,
      });
    }
  });

  test('baseline - empty state view', async ({ page }) => {
    // Navigate to empty state
    await page.goto('/app/messages?status=empty_test');
    await page.waitForTimeout(1000);
    
    // Capture empty state
    await expect(page).toHaveScreenshot('messages-empty-state.png', {
      fullPage: true,
      maxDiffPixels: 100,
    });
  });

  test('baseline - pagination controls', async ({ page }) => {
    // Find pagination area
    const pagination = page.locator('[data-testid="pagination"], .pagination, button[phx-click="next_page"]').first();
    
    if (await pagination.count() > 0) {
      // Capture pagination controls
      await expect(pagination).toHaveScreenshot('messages-pagination-controls.png', {
        maxDiffPixels: 50,
      });
    } else {
      // Fallback: capture bottom of page where pagination should be
      const body = page.locator('body');
      await expect(body).toHaveScreenshot('messages-pagination-area.png', {
        maxDiffPixels: 100,
      });
    }
  });

  test('baseline - error flash message', async ({ page }) => {
    // Try to trigger an error (e.g., delete a failing message)
    const deleteButton = page.locator('button[phx-click="delete"]').first();
    
    if (await deleteButton.count() > 0) {
      // Look for a message that might fail (if UI supports it)
      // For now, just capture the flash area
      const flashArea = page.locator('[role="alert"], .flash, [class*="alert"]').first();
      
      if (await flashArea.count() > 0) {
        await expect(flashArea).toHaveScreenshot('messages-error-flash.png', {
          maxDiffPixels: 50,
        });
      }
    }
    
    // If no error flash, capture empty flash area
    const flashContainer = page.locator('[data-testid="flash"], .flash-container').first();
    if (await flashContainer.count() > 0) {
      await expect(flashContainer).toHaveScreenshot('messages-flash-container.png', {
        maxDiffPixels: 30,
      });
    }
  });

  test('component - message table row', async ({ page }) => {
    // Capture a single message row
    const firstRow = page.locator('tbody tr, [data-testid="message-row"]').first();
    
    if (await firstRow.count() > 0) {
      await expect(firstRow).toHaveScreenshot('messages-table-row.png', {
        maxDiffPixels: 30,
      });
    }
  });

  test('component - filter dropdowns', async ({ page }) => {
    // Capture filter section
    const filters = page.locator('select[name="status"], select[name="type"]').first();
    
    if (await filters.count() > 0) {
      // Get parent container
      const filterContainer = filters.locator('..');
      await expect(filterContainer).toHaveScreenshot('messages-filter-dropdowns.png', {
        maxDiffPixels: 50,
      });
    }
  });
});

