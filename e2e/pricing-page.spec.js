// @ts-check
const { test, expect } = require('@playwright/test');

test.describe('Pricing Page', () => {
  test.beforeEach(async ({ page }) => {
    await page.goto('/pricing.html');
  });

  test('page loads with correct title', async ({ page }) => {
    await expect(page).toHaveTitle(/Pricing.*AutoSpotter/);
  });

  test('monthly plan prices — Free £0, Basic £9.99, Trader £59.99', async ({ page }) => {
    const free = page.locator('#card-free');
    await expect(free.locator('.plan-price')).toContainText('Free');

    const basic = page.locator('#card-basic');
    await expect(basic.locator('.plan-price')).toContainText('£9.99');

    const trader = page.locator('#card-trader');
    await expect(trader.locator('.plan-price')).toContainText('£59.99');
  });

  test('overage rates — Basic 90p, Trader 85p', async ({ page }) => {
    const basic = page.locator('#card-basic');
    await expect(basic).toContainText('90p');

    const trader = page.locator('#card-trader');
    await expect(trader).toContainText('85p');
  });

  test('pack prices — 10 Pack £8.99, 50 Pack £44.99, 100 Pack £84.99', async ({ page }) => {
    const packs = page.locator('#scan-packs-section');
    await expect(packs).toContainText('£8.99');
    await expect(packs).toContainText('£44.99');
    await expect(packs).toContainText('£84.99');
  });

  test('comparison table matches plan card prices and overage rates', async ({ page }) => {
    const table = page.locator('.compare-table');
    await expect(table).toBeVisible();

    // Monthly price row
    const priceRow = table.locator('tr', { hasText: 'Monthly price' });
    await expect(priceRow).toContainText('Free');
    await expect(priceRow).toContainText('£9.99');
    await expect(priceRow).toContainText('£59.99');

    // Additional reports row
    const overageRow = table.locator('tr', { hasText: 'Additional reports' });
    await expect(overageRow).toContainText('90p');
    await expect(overageRow).toContainText('85p');
  });

  test('plan cards have CTA buttons', async ({ page }) => {
    await expect(page.locator('#btn-free')).toBeVisible();
    await expect(page.locator('#btn-basic')).toBeVisible();
    await expect(page.locator('#btn-trader')).toBeVisible();
  });

  test('scan packs section is visible', async ({ page }) => {
    await expect(page.locator('#scan-packs-section')).toBeVisible();
    await expect(page.locator('text=Need More Scans?')).toBeVisible();
  });
});
