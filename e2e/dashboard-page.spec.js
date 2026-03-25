// @ts-check
const { test, expect } = require('@playwright/test');

test.describe('Dashboard Page (unauthenticated)', () => {
  test('shows auth gate when not signed in', async ({ page }) => {
    await page.goto('/dashboard.html');
    await expect(page).toHaveTitle(/Dashboard.*AutoSpotter/);
    await expect(page.locator('#gate-auth')).toBeVisible({ timeout: 10000 });
  });

  test('dashboard content is hidden when not signed in', async ({ page }) => {
    await page.goto('/dashboard.html');
    await page.waitForTimeout(3000); // Wait for auth state to resolve
    await expect(page.locator('#dash-content')).not.toBeVisible();
  });
});
