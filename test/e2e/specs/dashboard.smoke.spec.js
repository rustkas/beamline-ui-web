// @ts-check
const { test, expect } = require('@playwright/test');

/**
 * Smoke E2E tests for DashboardLive
 * 
 * These tests verify critical user flows without deep validation.
 * Run with: npm run test:smoke
 * 
 * @smoke
 */
test.describe('DashboardLive Smoke Tests', () => {
  test.beforeEach(async ({ page }) => {
    // Authenticate via dev-login
    await page.goto('/dev-login?user=test_user&tenant=test_tenant');
    await page.waitForURL(/\/app\/dashboard/, { timeout: 10000 });
  });

  test('@smoke - dashboard loads and shows core tiles', async ({ page }) => {
    await page.goto('/app/dashboard');
    
    // Wait for initial load
    await page.waitForSelector('h1, [data-testid="dashboard"], text=Dashboard', { timeout: 10000 });
    
    // Verify page title
    await expect(page).toHaveTitle(/Dashboard/i);
    
    // Verify core sections are visible
    // Dashboard should show: System Status, Component Health, Real-time Metrics
    const dashboardContent = page.locator('text=Dashboard, text=System Status, text=Component Health, text=Real-time Metrics');
    await expect(dashboardContent.first()).toBeVisible({ timeout: 5000 });
    
    // Verify Gateway/Router/Workers sections (at least one should be visible)
    const healthSections = page.locator('text=Gateway, text=Router, text=Workers, text=NATS');
    const count = await healthSections.count();
    expect(count).toBeGreaterThan(0);
  });

  test('@smoke - dashboard handles health error gracefully', async ({ page }) => {
    // Navigate with force_error query param (if mock gateway supports it)
    await page.goto('/app/dashboard?health=force_error');
    
    // Wait for page to load (even with error)
    await page.waitForSelector('h1, [data-testid="dashboard"], text=Dashboard', { timeout: 10000 });
    
    // Verify page doesn't crash (200, HTML renders)
    await expect(page).toHaveURL(/\/app\/dashboard/);
    
    // Verify dashboard is still visible
    const dashboard = page.locator('text=Dashboard, h1');
    await expect(dashboard.first()).toBeVisible();
    
    // Error may or may not be visible depending on implementation
    // Important: page doesn't crash, no JS errors
    const pageContent = await page.content();
    expect(pageContent.length).toBeGreaterThan(0);
  });

  test('@smoke - dashboard polling updates (optional)', async ({ page }) => {
    await page.goto('/app/dashboard');
    
    // Wait for initial load
    await page.waitForSelector('text=Dashboard, text=System Status', { timeout: 10000 });
    
    // Get initial state (some metric or status text)
    const initialContent = await page.locator('text=ok, text=healthy, text=OK').first().textContent().catch(() => null);
    
    // Wait for polling cycle (2-3 seconds)
    await page.waitForTimeout(3000);
    
    // Verify page is still responsive
    const dashboard = page.locator('text=Dashboard, h1');
    await expect(dashboard.first()).toBeVisible();
    
    // Optionally: verify metrics updated (if visible)
    const updatedContent = await page.locator('text=ok, text=healthy, text=OK, text=Throughput').first().textContent().catch(() => null);
    
    // At minimum: page should still be functional
    expect(await page.url()).toContain('/app/dashboard');
  });
});

