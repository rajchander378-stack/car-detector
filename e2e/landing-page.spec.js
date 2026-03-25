// @ts-check
const { test, expect } = require('@playwright/test');

test.describe('Landing Page — Firebase Hosting', () => {
  test('page loads with correct title', async ({ page }) => {
    await page.goto('/');
    await expect(page).toHaveTitle(/AutoSpotter/);
  });

  test('hero section is visible with heading and CTA', async ({ page }) => {
    await page.goto('/');
    await expect(page.locator('.hero h1')).toBeVisible();
    await expect(page.locator('.hero .hero-cta, .hero a.btn')).toBeVisible();
  });

  test('navigation links are present', async ({ page }) => {
    await page.goto('/');
    const nav = page.locator('nav');
    await expect(nav.getByRole('link', { name: /pricing/i })).toBeVisible();
    await expect(nav.getByRole('link', { name: /privacy/i })).toBeVisible();
    await expect(nav.getByRole('link', { name: /features/i })).toBeVisible();
  });

  test('how-it-works section exists', async ({ page }) => {
    await page.goto('/');
    await expect(page.locator('text=How it works').first()).toBeVisible();
  });

  test('features section exists', async ({ page }) => {
    await page.goto('/');
    await expect(page.locator('.features-grid, .features').first()).toBeVisible();
  });
});
