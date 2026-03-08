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

## REST API (if testing locally or deployed)

- [ ] **POST /identify** — Send a multipart image upload, confirm JSON response with car identification.
- [ ] **POST /identify?includeValuation=true** — Send image with a visible plate, confirm valuation data is included in response.
- [ ] **GET /health** — Confirm health endpoint returns 200 OK.
- [ ] **RapidAPI auth** — Send request without `X-RapidAPI-Proxy-Secret` header (when env var is set), confirm it is rejected.
- [ ] **Concurrent requests** — Send multiple requests simultaneously, confirm no temp file collisions or crashes.

## Firebase Hosting / Web Pages

- [ ] **Landing page** — Visit `https://car-detector-833e5.web.app/`, confirm landing page loads.
- [ ] **Privacy policy page** — Visit `/privacy-policy.html`, confirm it loads with correct content.
- [ ] **404 page** — Visit a non-existent URL, confirm custom 404 page appears.

---

## Notes

- Test on a **physical Android device** (not just emulator) for camera, haptics, and Google Sign-In.
- For valuation testing, sandbox mode only works with VRMs containing "A".
- Record any bugs found as separate GitHub Issues and link them here.
