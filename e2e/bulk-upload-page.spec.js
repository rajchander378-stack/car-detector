// @ts-check
const { test, expect } = require('@playwright/test');

test.describe('Bulk Upload Page (unauthenticated)', () => {
  test('shows auth gate when not signed in', async ({ page }) => {
    await page.goto('/bulk-upload.html');
    await expect(page).toHaveTitle(/Bulk Upload.*AutoSpotter/);
    await expect(page.locator('#gate-auth')).toBeVisible({ timeout: 10000 });
  });

  test('bulk content is hidden when not signed in', async ({ page }) => {
    await page.goto('/bulk-upload.html');
    await page.waitForTimeout(3000);
    await expect(page.locator('#bulk-content')).not.toBeVisible();
  });
});
