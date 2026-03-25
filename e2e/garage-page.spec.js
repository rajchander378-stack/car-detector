// @ts-check
const { test, expect } = require('@playwright/test');

test.describe('Garage Page (unauthenticated)', () => {
  test('shows auth gate when not signed in', async ({ page }) => {
    await page.goto('/garage.html');
    await expect(page).toHaveTitle(/Vehicles.*AutoSpotter|Garage.*AutoSpotter/i);
    // Auth state resolves via Firebase — wait for gate to appear
    await expect(page.locator('#gate-auth')).toBeVisible({ timeout: 20000 });
  });

  test('garage content is hidden when not signed in', async ({ page }) => {
    await page.goto('/garage.html');
    await page.waitForTimeout(3000);
    await expect(page.locator('#garage-content')).not.toBeVisible();
  });
});
