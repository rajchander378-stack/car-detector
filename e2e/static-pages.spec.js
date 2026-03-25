// @ts-check
const { test, expect } = require('@playwright/test');

test.describe('Privacy Policy Page', () => {
  test('loads with correct content', async ({ page }) => {
    await page.goto('/privacy-policy.html');
    await expect(page).toHaveTitle(/Privacy Policy.*AutoSpotter/);
    await expect(page.locator('text=Privacy Policy').first()).toBeVisible();
    // Check key sections exist
    await expect(page.locator('text=Information We Collect').first()).toBeVisible();
    await expect(page.locator('text=Data Retention').first()).toBeVisible();
    await expect(page.locator('text=Your Rights').first()).toBeVisible();
  });
});

test.describe('Disclaimer Page', () => {
  test('loads with correct content', async ({ page }) => {
    await page.goto('/disclaimer.html');
    await expect(page).toHaveTitle(/Disclaimer.*AutoSpotter/i);
    await expect(page.locator('text=Data Disclaimer').first()).toBeVisible();
    await expect(page.locator('text=Vehicle Valuations').first()).toBeVisible();
  });
});

test.describe('Contact Page', () => {
  test('loads with sign-in prompt for unauthenticated users', async ({ page }) => {
    await page.goto('/contact.html');
    await expect(page).toHaveTitle(/Contact.*AutoSpotter/);
    // Should show sign-in prompt when not authenticated
    await expect(page.locator('#sign-in-prompt')).toBeVisible({ timeout: 10000 });
  });
});

test.describe('Delete Account Page', () => {
  test('loads with deletion flow', async ({ page }) => {
    await page.goto('/delete-account.html');
    await expect(page).toHaveTitle(/Delete Account.*AutoSpotter/);
    await expect(page.locator('text=Account Deletion').first()).toBeVisible();
    await expect(page.locator('text=What Gets Deleted').first()).toBeVisible();
  });
});

test.describe('404 Page', () => {
  test('custom 404 page appears for non-existent URL', async ({ page }) => {
    const response = await page.goto('/this-page-does-not-exist-xyz');
    // Firebase hosting returns 404.html content but may return 200 status
    await expect(page.locator('text=404')).toBeVisible();
    await expect(page.locator('text=doesn\'t exist').first()).toBeVisible();
    await expect(page.getByRole('link', { name: /go to home/i })).toBeVisible();
  });
});
