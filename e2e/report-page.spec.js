// @ts-check
const { test, expect } = require('@playwright/test');

test.describe('Report Page', () => {
  test('report not found — shows error state for nonexistent ID', async ({ page }) => {
    await page.goto('/report.html?id=nonexistent');
    await expect(page).toHaveTitle(/Report.*AutoSpotter/i);
    // Wait for Firestore query to resolve and show error
    await expect(page.locator('#error-state')).toBeVisible({ timeout: 15000 });
  });

  test('report page loads without ID — shows error state', async ({ page }) => {
    await page.goto('/report.html');
    // Without an ID, showError() is called immediately — but Firebase SDK must load first
    await expect(page.locator('#error-state')).toBeVisible({ timeout: 20000 });
  });

  test('mobile responsive — layout is readable on narrow screen', async ({ page, isMobile }) => {
    test.skip(!isMobile, 'Mobile-only test');
    await page.goto('/report.html?id=nonexistent');
    // Check viewport is narrow and page doesn't overflow
    const body = page.locator('body');
    const box = await body.boundingBox();
    expect(box.width).toBeLessThanOrEqual(400);
  });
});
