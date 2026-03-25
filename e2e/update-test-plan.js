/**
 * Reads Playwright JSON results and updates checkboxes in test_plan_github_issue.md
 *
 * Mapping: test title substring → test plan checkbox line substring
 */
const fs = require('fs');
const path = require('path');

const RESULTS_PATH = path.join(__dirname, '..', 'playwright-results.json');
const PLAN_PATH = path.join(__dirname, '..', 'test_plan_github_issue.md');

// Map from test name pattern to the checkbox text it covers
const TEST_TO_PLAN = [
  // Landing page
  { test: 'Landing Page.*page loads', plan: 'Landing page' },
  // Pricing
  { test: 'monthly plan prices', plan: 'Monthly plan prices' },
  { test: 'overage rates', plan: 'Overage rates' },
  { test: 'pack prices', plan: 'Pack prices' },
  { test: 'comparison table matches', plan: 'Comparison table' },
  // Static pages
  { test: 'Privacy Policy.*loads with correct content', plan: 'Privacy policy page' },
  { test: 'Disclaimer.*loads with correct content', plan: 'Disclaimer page' },
  { test: 'Contact.*loads', plan: 'Contact page' },
  { test: 'Delete Account.*loads with deletion flow', plan: 'Delete account page' },
  { test: '404.*custom 404 page', plan: '404 page' },
  // Auth-gated pages
  { test: 'Dashboard.*shows auth gate', plan: 'Dashboard page' },
  { test: 'Garage.*shows auth gate', plan: 'Garage page' },
  { test: 'Bulk Upload.*shows auth gate', plan: 'Bulk upload page' },
  // Report
  { test: 'report not found', plan: 'Report not found' },
  { test: 'mobile responsive', plan: 'Mobile responsive' },
];

function run() {
  if (!fs.existsSync(RESULTS_PATH)) {
    console.error('No results.json found. Run tests first.');
    process.exit(1);
  }

  const results = JSON.parse(fs.readFileSync(RESULTS_PATH, 'utf8'));
  let plan = fs.readFileSync(PLAN_PATH, 'utf8');

  // Collect passed test titles (from all suites)
  const passedTests = new Set();
  const failedTests = new Set();

  function walk(suite) {
    if (suite.specs) {
      for (const spec of suite.specs) {
        const title = (suite.title ? suite.title + ' ' : '') + spec.title;
        const passed = spec.tests.some(t => t.results.some(r => r.status === 'passed'));
        const failed = spec.tests.some(t => t.results.some(r => r.status === 'failed'));
        if (passed) passedTests.add(title);
        if (failed) failedTests.add(title);
      }
    }
    if (suite.suites) {
      for (const child of suite.suites) {
        walk({ ...child, title: (suite.title ? suite.title + ' ' : '') + (child.title || '') });
      }
    }
  }

  for (const suite of results.suites) {
    walk(suite);
  }

  let checked = 0;
  const allTitles = [...passedTests].join(' ||| ');

  for (const mapping of TEST_TO_PLAN) {
    const regex = new RegExp(mapping.test, 'i');
    const matched = [...passedTests].some(t => regex.test(t));
    if (matched) {
      // Find the checkbox line in the plan and check it
      const planRegex = new RegExp(
        `- \\[ \\] (\\*\\*)?${escapeRegex(mapping.plan)}`,
        'i'
      );
      if (planRegex.test(plan)) {
        plan = plan.replace(planRegex, (match) => match.replace('- [ ]', '- [x]'));
        checked++;
        console.log(`  ✓ ${mapping.plan}`);
      }
    }
  }

  fs.writeFileSync(PLAN_PATH, plan, 'utf8');
  console.log(`\nUpdated ${checked} checkboxes in test_plan_github_issue.md`);

  // Summary
  console.log(`\nTest summary: ${passedTests.size} passed, ${failedTests.size} failed`);
}

function escapeRegex(str) {
  return str.replace(/[.*+?^${}()|[\]\\]/g, '\\$&');
}

run();
