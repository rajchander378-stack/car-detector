# AutoSpotter — Manual Test Plan

Test each completed feature on a physical device. Tick the box when verified working.

---

## Core AI Identification

- [ ] **Instant AI Car Identification** — Point camera at a car, confirm it returns make, model, year range, generation, trim level, body style, colour, confidence score (0-100%), and distinguishing features.
- [ ] **Smart Image Processing** — Verify images are optimised before sending to Gemini (no excessively large uploads). Test with underexposed/overexposed photos and confirm quality warnings appear.
- [ ] **UK-Localised Output** — Confirm AI results use UK English spelling (e.g. "colour" not "color") and UK body style names (e.g. "saloon" not "sedan", "estate" not "wagon").

## Number Plate Reading

- [ ] **Number plate detection via Gemini** — Point at a car with a visible plate, confirm the plate text is returned in the results.
- [ ] **Number plate display on results screen** — Verify the detected plate appears in the specs table (UK-style yellow plate widget).
- [ ] **No plate visible** — Test with an image where no plate is visible, confirm the app handles it gracefully (no crash, field absent or shows N/A).

## Price Estimation / Valuation

- [ ] **Valuation button appears** — After identification with a number plate, confirm the valuation button is visible on the results screen.
- [ ] **Valuation fetches correctly** — Tap valuation button, confirm retail/trade/private prices load with loading spinner.
- [ ] **Valuation error handling** — Test with an invalid/sandbox plate, confirm a styled error banner with retry button appears (not a raw error string).
- [ ] **Shimmer loading placeholder** — Confirm a pulsing shimmer skeleton shows while valuation is loading (not a plain spinner).
- [ ] **Animated price reveal** — Confirm prices fade + slide up when they load.

## Camera Screen

- [ ] **Camera preview launches** — Camera screen opens and shows a live preview.
- [ ] **Prominent Disclosure dialog** — On first launch, a custom dialog explains camera usage BEFORE the system permission prompt appears.
- [ ] **Viewfinder overlay** — Rounded rectangle guide with "Align vehicle within frame" hint text is visible.
- [ ] **Capture button haptic feedback** — Tapping capture triggers haptic feedback and a white flash overlay.
- [ ] **Processing overlay** — After capture, pulsing car icon, stage-based status text ("Optimising image..." then "Asking AI to identify..."), and progress bar appear.
- [ ] **Offline check** — Turn off WiFi/data, tap capture, confirm "No internet connection" snackbar appears.
- [ ] **Processing lock** — Tap capture rapidly, confirm only one identification runs (no duplicate submissions).
- [ ] **Settings button** — Settings icon is visible and navigates to the settings screen.

## Results Screen

- [ ] **Split-screen layout** — Captured photo on top with gradient overlay, specs below.
- [ ] **Confidence gauge** — Circular arc gauge with colour-coded arc (green/orange/red) and percentage in centre.
- [ ] **Vehicle spec chips** — Colour, body style, generation, and trim displayed as Material chips with icons.
- [ ] **Valuation card design** — Gradient card with shadow, hero price range, dealer/private/trade tier grid, mileage row.
- [ ] **UK plate styled display** — Number plate shown in UK-style yellow plate widget with bold text and border.
- [ ] **Notable features list** — AI observation notes and distinguishing features are displayed.
- [ ] **Error state** — Test with a non-car image, confirm "vehicle not recognised" state with orange car icon, guidance text, and retry button.
- [ ] **Retry button** — Tap retry from results screen, confirm it returns to camera for a new capture.
- [ ] **AI result reporting** — "Report inaccurate result" button is visible and logs a report to Firestore when tapped.

## Authentication & User Accounts

- [ ] **Google Sign-In** — Tap sign in with Google, confirm sign-in completes and navigates to camera screen.
- [ ] **Auth gate** — Launch app without signing in, confirm it routes to the login screen (not camera).
- [ ] **Sign-out** — Open settings, tap sign-out, confirm confirmation dialog appears. Confirm sign-out returns to login screen.
- [ ] **Terms acceptance persists** — Accept terms, force-close app, relaunch, confirm terms are NOT shown again.

## Account & Data Deletion

- [ ] **In-app account deletion** — Navigate to settings, confirm delete account option exists and works.
- [ ] **Web deletion page** — Visit `https://car-detector-833e5.web.app/delete-account.html`, confirm the page loads with an email request option.

## Settings & About

- [ ] **App version display** — Settings screen shows the correct version number from `package_info_plus`.
- [ ] **About dialog** — About dialog shows version, copyright, contact email.
- [ ] **Privacy policy link** — Link to hosted privacy policy page works and opens in browser.
- [ ] **Terms link** — Terms screen links to the hosted privacy policy page (not a local markdown file).

## Accessibility

- [ ] **Semantic labels** — Enable TalkBack/VoiceOver, confirm capture button, processing overlay, history button, settings button, vehicle name, and confidence indicator are all announced.

## UI Polish & Transitions

- [ ] **Smooth page transition** — Fade transition from camera to results screen with Hero widget on the captured image.
- [ ] **Consistent theme** — Material 3 theme with rounded cards/chips/buttons, centred app bar titles, consistent spacing throughout the app.
- [ ] **Consistent error styling** — Errors across login, camera, results, and settings all show user-friendly messages (no raw exception strings like `$e.toString()`).

## Full Vehicle Report (DataPackage2)

- [ ] **Report button label** — Confirm button reads "Get Full Vehicle Report" (not "Get Price Estimate").
- [ ] **Vehicle Details section** — After fetching report, confirm expandable "Vehicle Details" section appears with VRM, VIN, make, model, fuel type, body type, colour, year, first registered, engine CC, keepers, road tax, CO2.
- [ ] **Warning chips** — If vehicle is imported/exported/scrapped, confirm red warning chips appear in Vehicle Details.
- [ ] **MOT History section** — Confirm expandable "MOT History" section appears with due date banner, pass/fail summary, and individual test cards.
- [ ] **MOT overdue indicator** — Test with a vehicle whose MOT is overdue, confirm the section header and banner turn red.
- [ ] **MOT defects** — Confirm failed MOT tests show failure defects listed beneath the test card.
- [ ] **Specifications section** — Confirm expandable "Specifications" section shows engine, transmission, drive type, 0-60, top speed, fuel economy, CO2, NCAP rating, weight, dimensions.
- [ ] **EV details** — Test with an electric vehicle, confirm battery capacity, real range, and max charge power appear.
- [ ] **Tyres & Wheels section** — Confirm expandable section shows front/rear tyre sizes, pressures, run-flat status, PCD, wheel torque.
- [ ] **Saved scan detail shows report** — Open a saved scan that has full report data, confirm all four expandable sections display correctly.
- [ ] **Legacy scan compatibility** — Open an older saved scan (report version 1, valuation only), confirm it still displays correctly without crashing.

## Duplicate Scan Detection

- [ ] **Warn before re-scanning same plate** — Scan a vehicle, save it. Scan the same plate again and tap "Get Full Vehicle Report". Confirm a dialog warns that an existing report was found with the date, and offers "Cancel" or "Fetch New Report".
- [ ] **Cancel avoids credit usage** — Tap "Cancel" on the duplicate warning, confirm no API call is made and no credit is used.
- [ ] **Fetch New Report uses credit** — Tap "Fetch New Report", confirm the API call proceeds and a credit is consumed.
- [ ] **Save offers overwrite** — After fetching a new report for a plate that's already saved, tap "Save Report". Confirm a dialog offers "Update Existing", "Save New", or "Cancel".
- [ ] **Update Existing overwrites** — Choose "Update Existing", confirm the old saved scan is updated with the new data (not duplicated).
- [ ] **Save New creates second entry** — Choose "Save New", confirm a separate entry appears in saved scans.
- [ ] **Different plates skip warning** — Scan a vehicle with a plate not in saved scans, confirm no duplicate warning appears.

## Saved Scans & Garage

- [ ] **Saved scans list** — Navigate to saved scans, confirm all saved scans appear sorted by date (newest first).
- [ ] **Favourites tab** — Tap "Favourites" tab, confirm only favourited scans appear.
- [ ] **Toggle favourite** — Open a saved scan detail, tap the star icon, confirm it toggles and persists on reload.
- [ ] **Delete scan** — Open a saved scan detail, tap delete, confirm dialog appears. Confirm deletion removes the scan.
- [ ] **Scan expiry warning** — Open a scan older than 90 days, confirm the "Prices may be stale" badge and orange warning appear.
- [ ] **Garage badge — Save to Garage** — On the web dashboard, confirm scans not in the garage show a green "Save to Garage" button.
- [ ] **Garage badge — Remove from Garage** — Save a scan to the garage, confirm the button flips to red "Remove from Garage".
- [ ] **Remove from Garage** — Click "Remove from Garage", confirm the vehicle is removed and the button flips back to "Save to Garage".
- [ ] **Garage badge persists on reload** — Reload the dashboard, confirm buttons still show the correct state for each scan.
- [ ] **Garage limit enforcement** — On a Free plan (limit 2), save 2 vehicles to garage, try to add a third, confirm limit alert appears.

## CSV Export

- [ ] **Export button visible** — Navigate to saved scans screen, confirm the download icon is visible in the app bar.
- [ ] **Trader plan required** — On a non-Trader plan, tap export, confirm "Trader Plan Required" dialog appears.
- [ ] **CSV generates on Trader plan** — On Trader plan, tap export with saved scans, confirm a CSV file is generated and the share sheet opens.
- [ ] **CSV contents** — Open the exported CSV, confirm it contains all columns: identification, valuation, vehicle details (VIN, fuel, engine, keepers, tax, CO2, imported, scrapped), MOT (due, passes, failures, last result, mileage), specs (transmission, drive, 0-60, top speed, MPG, NCAP, weight), tyres (front, rear), favourite.
- [ ] **Empty scans** — Tap export with no saved scans, confirm "No scans to export" snackbar appears.

## Plans & Pricing

- [ ] **Monthly plan prices** — Confirm pricing page shows Free (£0), Basic (£9.99/mo), Trader (£59.99/mo).
- [ ] **Overage rates** — Confirm pricing page shows Basic overage at 90p, Trader overage at 85p.
- [ ] **Pack prices** — Confirm pricing page shows 10 Pack (£8.99), 50 Pack (£44.99), 100 Pack (£84.99).
- [ ] **Comparison table** — Confirm the plan comparison table matches the plan card prices and overage rates.
- [ ] **Debug plan switcher** — In debug mode, open settings, confirm the segmented plan switcher (Free/Basic/Trader) is visible.
- [ ] **Debug plan switcher works** — Switch to Trader via the debug switcher, confirm plan changes immediately and features unlock.
- [ ] **Debug switcher hidden in release** — Build a release version, confirm the plan switcher is NOT visible in settings.
- [ ] **Free plan blocks valuations** — On Free plan, tap "Get Full Vehicle Report", confirm "Upgrade Required" dialog appears.
- [ ] **Overage confirmation** — Exhaust monthly scan allowance, tap report button, confirm overage cost dialog appears with correct price.

## Stripe & Scan Credits

- [ ] **Pack purchase flow** — Click "Buy 10 Scans" on pricing page, confirm it creates a Stripe Checkout session and redirects.
- [ ] **Credits added after purchase** — Complete a test purchase, confirm scan credits are incremented in Firestore.
- [ ] **Purchase success banner** — After returning from Stripe, confirm the dashboard shows "Payment successful!" banner.
- [ ] **Webhook signature verification** — Send a webhook request without valid signature, confirm it is rejected (401).
- [ ] **Webhook timestamp freshness** — Send a webhook with a timestamp older than 5 minutes, confirm it is rejected.
- [ ] **Empty webhook secret** — If `STRIPE_WEBHOOK_SECRET` is not set, confirm webhook endpoint returns 500 (not silently skipping verification).
- [ ] **Atomic credit increment** — Purchase credits from two sessions simultaneously, confirm both are correctly added (no race condition).

## Web Report Page

- [ ] **Shared report loads** — Share a report from the dashboard, open the link, confirm the report page loads with vehicle identification and valuation.
- [ ] **Vehicle Details section** — Confirm the collapsible Vehicle Details section appears and expands on click.
- [ ] **MOT History section** — Confirm MOT section shows due date banner, pass/fail summary, and test cards.
- [ ] **Specifications section** — Confirm specs section shows engine, transmission, performance, economy, NCAP rating.
- [ ] **Tyres section** — Confirm tyres section shows front/rear sizes, pressures, PCD, torque.
- [ ] **Collapse/expand toggle** — Click a section header, confirm it expands. Click again, confirm it collapses.
- [ ] **Report not found** — Visit `/report.html?id=nonexistent`, confirm "Report Not Found" error state appears.
- [ ] **Mobile responsive** — View the report page on a narrow screen, confirm layout is readable and sections stack correctly.

## REST API (if testing locally or deployed)

- [ ] **POST /identify** — Send a multipart image upload, confirm JSON response with car identification.
- [ ] **POST /identify?includeValuation=true** — Send image with a visible plate, confirm valuation data is included in response.
- [ ] **GET /health** — Confirm health endpoint returns 200 OK.
- [ ] **API auth** — Send request without `X-API-Secret` header (when env var is set), confirm it is rejected.
- [ ] **Concurrent requests** — Send multiple requests simultaneously, confirm no temp file collisions or crashes.

## Firebase Hosting / Web Pages

- [ ] **Landing page** — Visit `https://car-detector-833e5.web.app/`, confirm landing page loads.
- [ ] **Privacy policy page** — Visit `/privacy-policy.html`, confirm it loads with correct content.
- [ ] **Pricing page** — Visit `/pricing.html`, confirm plan cards, pack cards, and comparison table load with correct prices.
- [ ] **Dashboard page** — Sign in on `/dashboard.html`, confirm stats, plan card, usage bar, saved scans, and quick actions load.
- [ ] **Garage page** — Sign in on `/garage.html`, confirm saved vehicles load with limit info and remove buttons.
- [ ] **Report page** — Visit `/report.html?id=<valid_id>`, confirm full report loads with all sections.
- [ ] **Disclaimer page** — Visit `/disclaimer.html`, confirm it loads.
- [ ] **Contact page** — Visit `/contact.html`, confirm it loads.
- [ ] **Bulk upload page** — Sign in as Trader on `/bulk-upload.html`, confirm it loads.
- [ ] **Delete account page** — Visit `/delete-account.html`, confirm it loads with the deletion flow.
- [ ] **Admin page** — Sign in as admin on `/admin/`, confirm it loads.
- [ ] **404 page** — Visit a non-existent URL, confirm custom 404 page appears.
- [ ] **Staging deployment** — Run `firebase hosting:channel:deploy staging --expires 7d`, confirm staging URL works.

---

## Notes

- Test on a **physical Android device** (not just emulator) for camera, haptics, and Google Sign-In.
- For valuation testing, sandbox mode only works with VRMs containing "A".
- Use the **debug plan switcher** in Settings (debug builds only) to test Free/Basic/Trader features without paying.
- Stripe webhook tests require a Stripe CLI or test webhook events.
- The DataPackage2 API integration requires the correct package to be configured with VehicleDataGlobal — test data may be limited until this is confirmed.
- Web page tests should be run on the **staging URL** (`staging-mtqnxfja.web.app`), not production.
- Record any bugs found as separate GitHub Issues and link them here.
