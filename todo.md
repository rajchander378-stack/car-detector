# Car Detector — Feature Tracker

## Useful Commands

| Command | When to use |
|---|---|
| `taskkill /F /IM java.exe` | Gradle lock error — kills stuck Java/Gradle daemons that are holding a stale lock file |
| `rm ~/.gradle/caches/jars-9/jars-9.lock` | Gradle lock error — removes the stale lock file after killing the Java processes |
| `flutter clean` | After clearing a Gradle lock, or when builds behave unexpectedly — wipes all build artefacts so the next build starts fresh |
| `flutter run` | Run the app on a connected device or emulator |
| `flutter pub get` | After changing `pubspec.yaml` — downloads new/updated dependencies |

**Tip:** Gradle lock errors usually happen when VS Code or a terminal is closed mid-build. Wait for builds to finish before closing, and avoid running `flutter run` from multiple terminals at the same time.

---

## Completed

- [x] **Instant AI Car Identification** — Point camera at any car for instant identification powered by Google Gemini 2.5 Flash. Returns make, model, year range, generation, trim level, body style, and colour with a confidence score (0–100%) and distinguishing visual features.
- [x] **Smart Image Processing** — Automatic image optimisation before AI analysis (resize to 1024px, JPEG compression). Image quality assessment detects underexposure, overexposure, and insufficient resolution. Vehicle cropping with intelligent 10% margin padding.
- [x] **On-Device Vehicle Detection (ML Kit)** — Local ML-based object detection using Google ML Kit. Classifies vehicle types: car, van, truck, motorcycle, bus, SUV. Runs on-device with no network needed for the detection step. **Note:** Default ML Kit model cannot detect vehicles — a custom COCO-trained `.tflite` model is needed (see Future tasks below).
- [x] **Beautiful Results Display** — Split-screen layout with captured photo on top and specs below. Colour-coded confidence bar (green/orange/red), full specifications table, notable features list, and AI observation notes. Clear error messaging when identification fails.
- [x] **Real-Time Status Feedback** — Live status updates during processing ("Detecting vehicle...", "Identifying car...", "Asking Gemini..."). Processing lock prevents duplicate submissions. One-tap retry from the results screen.
- [x] **Cross-Platform Support** — Single Flutter codebase targeting Android, iOS, Web, Windows, macOS, and Linux with platform-specific Firebase configurations.
- [x] **Firebase Backend Integration** — Firebase Core initialisation, Firebase Auth configured (ready for user accounts), and Firebase AI integration for Gemini access with no separate API key management.
- [x] **UK-Localised Output** — AI tuned to use UK English spelling and terminology with UK body style naming (saloon, estate, etc.).

## In Progress — Pre-Vehicle Detection & Number Plate Reading

### Number Plate via Gemini (Quick Win)
- [x] **Add `number_plate` field to Gemini schema** — Extend `_carSchema` in `gemini_service.dart` with a nullable `number_plate` string field so Gemini returns the plate text if visible.
- [x] **Update Gemini prompt to request plate** — Modify the `TextPart` prompt to ask Gemini to read the number plate if visible.
- [x] **Add `numberPlate` to `CarIdentification` model** — Add the field to the constructor, `fromJson()`, and `toJson()` in `car_identification.dart`.
- [x] **Display number plate on results screen** — Show the plate in the specs table on `results_screen.dart` when available.

### Pre-Vehicle Detection Gate
- [x] **Re-enable vehicle detection in camera flow** — Detection gate implemented but currently bypassed until a custom COCO-trained `.tflite` model is bundled. Flow goes straight to Gemini for now.
- [x] **Add note about ML Kit default model limitation** — The default ML Kit model does NOT detect vehicles (only home goods, fashion, food, plants, places). Document this in code comments and `todo.md`. A custom `.tflite` model (e.g. EfficientDet Lite trained on COCO) must be bundled as a future task for reliable detection.

### Future — On-Device Plate Detection (Offline Pipeline)
- [ ] **Bundle a plate-detection TFLite model** — Source a YOLOv8 or EfficientDet `.tflite` model trained on licence plates (e.g. from Roboflow Universe) and add to app assets.
- [ ] **Add `google_mlkit_text_recognition` for plate OCR** — After cropping to the plate region, run ML Kit text recognition on-device for offline plate reading.
- [ ] **Bundle a vehicle-detection TFLite model** — Replace the default ML Kit model with a COCO-trained `.tflite` (e.g. EfficientDet Lite) that reliably detects cars, trucks, vans, motorcycles.

## Completed — REST API (Cloud Run)

- [x] **Car Detector REST API** — Standalone Dart server in `api/` directory exposing the car identification pipeline as a REST API. `POST /identify` accepts multipart image upload, runs image optimisation + AI identification, and returns JSON. Query param `includeValuation=true` auto-fetches UK valuation data when a plate is detected. `GET /health` for Cloud Run health checks.
- [x] **Auth Middleware** — Validates API secret header. Open/dev mode when env var is unset. `/health` always bypasses auth.
- [x] **Server-Side AI Integration** — Rewrote `gemini_service.dart` to use `google_generative_ai` (server-side SDK) with `DataPart` instead of `firebase_ai`'s `InlineDataPart`. Same schema, prompt, and temperature as Flutter app.
- [x] **Concurrent-Safe Image Processing** — Adapted `image_processor.dart` with unique temp file suffixes to avoid collisions under concurrent requests. Removed `cropToVehicle()` (depends on `dart:ui`).
- [x] **Docker + Cloud Run Ready** — 2-stage AOT Dockerfile (dart:3.3 build → dart:3.3-slim runtime). Non-root user. Configurable via `GEMINI_API_KEY`, `UKVD_API_KEY`, `PORT` env vars.
- [x] **OpenAPI 3.0 Spec** — Full `openapi.yaml` documenting both endpoints and request/response schemas.

## Uncompleted — Other Features

- [x] **Price Estimation** — Get price estimates via UK Vehicle Data API using the number plate. Button on results screen fetches retail/trade/private valuations with loading spinner and error handling. Requires a valid API key in `constants.dart`. Sandbox mode limited to VRMs containing "A".
- [x] **Identification History** — Track past identifications. History button exists in camera UI and storage dependency included but not functional.
- [x] **Manual Edit/Correction** — Allow users to override AI results with manual search and correction. Bottom sheet form on results screen lets users edit make, model, year range, generation, trim, body style, colour, and number plate. Saving resets valuation so the user can re-fetch with corrected data.
- [x] **Gallery Upload** — Identify cars from existing photos. Gallery button on camera screen (bottom-left) and in drawer menu. Uses `image_picker` to select photo, runs through optimise + Gemini pipeline. Also added Sample Images screen with bundled placeholder images for demo/testing (accessible from drawer).
- [ ] **Extended Vehicle Support** — Full identification support for vans, trucks, and motorcycles (currently marked "coming soon").
- [x] **User Accounts — Google Sign-In** — Google Sign-In with Firebase Auth and Firestore user profiles. Auth gate in main.dart routes unauthenticated users to login screen.
- [x] **Scan History Persistence in Firestore** — Save past identifications to Firestore under each user's account. Saved under `users/{uid}/saved_scans/` with 90-day data retention policy (subject to GDPR review). Save prompt appears when leaving Vehicle Report screen with unsaved valuation data.
- [x] **Favourites / Bookmarking** — Allow users to bookmark/favourite car identifications. Star toggle on saved scan detail screen. Dedicated Favourites tab in Saved Scans screen. Accessible from drawer menu.
- [x] **Sign-Out Button on Camera Screen** — Add a sign-out option accessible from the camera screen.

## Uncompleted — Admin Lockout Dashboard

- [x] **Lockout event logging** — `LockoutService` logs to `lockout_events` collection with user ID, email, timestamp, device info (OS, version, locale), and error type list from each failed attempt. Integrated in `camera_screen.dart` lockout flow.
- [x] **Admin web dashboard** — Standalone HTML/JS page at `public/admin/index.html` using Firebase JS SDK (compat). Table view with user, timestamp, device, error details, and status columns. Stats cards for total/new/today/resolved. Filter buttons for all/new/acknowledged/resolved. Acknowledge and resolve actions per event. Deployed via Firebase Hosting at `/admin/`.
- [x] **Admin authentication** — Google Sign-In on dashboard, checked against `config/admin` Firestore document `admin_emails` array. First sign-in auto-creates the admin config. Non-admin users see "Access denied".
- [x] **Real-time alerts** — Dashboard uses `onSnapshot` Firestore listener for real-time updates. New lockout events appear instantly without page refresh.
- [x] **Lockout database schema** — Firestore collection `lockout_events`: `{ user_id, user_email, timestamp, device_info: { os, os_version, locale }, failure_errors: [String], resolved: bool, resolved_by: String?, resolved_at: Timestamp?, acknowledged: bool, acknowledged_by: String?, acknowledged_at: Timestamp? }`.

## Removed — Admin User Management Dashboard (Flutter Web)
> Removed — all proposed features (user list, disable/enable accounts, usage stats, search/filtering) are available directly in the Firebase Console. The existing HTML/JS lockout dashboard at `public/admin/` covers the remaining admin need.
> Firestore security rules for admin are already in place (`firestore.rules`).

## Uncompleted — Google Play Release Preparation

### BLOCKERS — Must fix before submission
- [x] **Prominent Disclosure dialog for camera** — Show a custom dialog explaining camera usage ("AutoSpotter uses your camera to capture vehicle images for AI identification and valuation") BEFORE the system permission prompt. Without this, Google will reject the app. Add to camera_screen.dart on first launch.
- [x] **Account and data deletion** — In-app deletion via Settings screen + web-based deletion page at `public/delete-account.html` with email request option. Will be live at `https://car-detector-833e5.web.app/delete-account.html` after deploy.
- [x] **AI result reporting feature** — Add a "Report inaccurate result" button on the results screen. Log reports to a Firestore `ai_reports` collection. Required under Google's 2026 AI-Generated Content Policy.
- [x] **Declare permissions in AndroidManifest.xml** — Add `<uses-permission android:name="android.permission.CAMERA"/>` and `<uses-permission android:name="android.permission.INTERNET"/>`. App will crash on fresh installs without these.
- [x] **Change applicationId** — Changed to `com.axiomforgesoftware.autospotter` in `build.gradle.kts`, updated namespace and moved `MainActivity.kt` to new package. **ACTION REQUIRED:** Add a new Android app in Firebase Console with package name `com.axiomforgesoftware.autospotter`, add the debug SHA-1 fingerprint, download the new `google-services.json`, and replace `android/app/google-services.json`.
- [x] **Host a privacy policy** — Full privacy policy created at `public/privacy-policy.html` covering: data collected, third-party sharing (Gemini, UK vehicle data API), retention/deletion, GDPR/UK DPA rights, lawful basis, children's privacy. Will be live at `https://car-detector-833e5.web.app/privacy-policy.html` after deploy. **Review the contact email** (`privacy@axiomforgesoftware.com`) and update if needed before deploying.
- [ ] **HIGH PRIORITY — Demo credentials for Google reviewer** — Create a new Google account (needs a phone number for setup). Sign into AutoSpotter with it to verify it works. Provide credentials in the "App Access" section of Play Console so the reviewer can test the app.
- [ ] **HIGH PRIORITY — Update google-services.json** — Add a new Android app in Firebase Console with package name `com.axiomforgesoftware.autospotter`, add the debug SHA-1 fingerprint (`3D:4D:4C:1C:7D:48:81:D1:2D:82:23:FF:61:54:80:39:B4:0D:B7:08`), download the new `google-services.json`, and replace `android/app/google-services.json`. **The app will not build until this is done.**
- [ ] **HIGH PRIORITY — Number plate GDPR compliance** — VRMs are personal data under UK law when linked to other info. Verify plates are not persisted anywhere (Firestore, logs, Gemini). If scan history is added later, document a lawful basis (consent or legitimate interest). Consider a Data Protection Impact Assessment (DPIA) as recommended by the ICO for ANPR-like features.
- [x] **Persist terms acceptance** — `_termsAccepted` in main.dart is in-memory only; users see terms on every app launch. Save acceptance to `shared_preferences` or Firestore so it persists across sessions.
- [x] **Set up Firebase Hosting** — Added hosting config to `firebase.json` with `public/` directory. Created landing page, privacy policy, account deletion page, shared CSS, and 404 page. **To deploy:** run `firebase deploy --only hosting` to publish to `https://car-detector-833e5.web.app/`.

### Technical (we can do these)
- [ ] **Release signing keystore** — Generate an upload keystore (`keytool -genkey`), create a `key.properties` file, and configure `signingConfigs` in `build.gradle.kts` for release builds. Keep the keystore safe — losing it means you cannot update the app.
- [x] **Update app metadata** — Changed pubspec.yaml description to "Instant AI car identification and UK vehicle valuation by Axiom Forge Software."
- [x] **App icon** — Design and configure a proper launcher icon (adaptive icon for Android). Consider using the `flutter_launcher_icons` package.
- [x] **Splash screen** — Configure a branded splash screen using `flutter_native_splash` or native Android splash.
- [ ] **Build release APK/AAB** — Run `flutter build appbundle --release` to produce the Android App Bundle for Play Store upload.
- [ ] **Test release build** — Install and test the release build on a physical device before submission. Verify camera, Google Sign-In, Gemini API, and valuation all work in release mode.
- [ ] **ProGuard / R8 rules** — Ensure minification doesn't break Firebase, ML Kit, or other plugins. Add keep rules if needed.
- [ ] **Add SHA-1 for release keystore to Firebase** — The release keystore will have a different SHA-1 from debug. Add it in Firebase Console for Google Sign-In to work in release builds.

### Policy & Compliance (ask Gemini — see prompt below)
- [x] **Privacy policy** — Required by Google Play for apps using camera, user accounts, and network requests. Must be hosted at a public URL.
- [ ] **Data safety declaration** — Google Play requires you to declare what data is collected, shared, and how it is secured.
- [ ] **Content rating questionnaire** — Complete the IARC rating questionnaire in Play Console.
- [x] **Camera and permissions disclosure** — Ensure compliance with Google Play's photo/video permissions policy.
- [ ] **Store listing assets** — Screenshots (phone + tablet), feature graphic (1024x500). Short and full descriptions drafted in `store_listing.txt`.
- [ ] **Google Play Developer account** — Register at play.google.com/console (one-time fee).

### Gemini Prompt for Google Play Policy Guidance

> Copy and paste the following into Google Gemini to get current guidance:

```
I am preparing to publish my first Android app on Google Play. The app is called "AutoSpotter" and it does the following:

- Uses the device camera to photograph cars and identify them using Google Gemini AI
- Reads number plates from the camera image
- Uses Google Sign-In with Firebase Auth for user accounts
- Stores user profiles (name, email, photo URL, login dates) in Cloud Firestore
- Sends captured images to Google Gemini 2.5 Flash API for AI identification
- Fetches UK vehicle valuation data from a third-party API using detected number plates
- Stores scan history and usage data per user

Based on the CURRENT Google Play Developer policies and requirements as of today, please advise me on:

1. What privacy policy do I need, and what must it include given I use camera, collect user data via Google Sign-In, store data in Firestore, and send images to an external AI API?
2. What do I need to declare in the Data Safety section of Play Console for the data I collect and transmit?
3. Are there specific Google Play policies around camera usage, photo capture, and number plate/license plate reading I need to comply with?
4. What permissions disclosures or prominent disclosure dialogs are required before accessing the camera?
5. Do I need to comply with any AI-specific policies given I use Gemini to analyse user-submitted images?
6. What content rating should I expect from the IARC questionnaire for this type of app?
7. Are there any UK/EU-specific requirements (GDPR, UK Data Protection Act) I should address before publishing, given the app reads UK number plates and fetches UK vehicle data?
8. What are the current requirements for store listing assets (screenshots, graphics, descriptions)?
9. Is there anything else I might be missing for a first-time Android app submission?

Please provide current, specific guidance rather than generic advice. Link to relevant Google Play policy pages where possible.
```

## Release & Update Checklist

Use this checklist each time you release a new version to Google Play.

### First-Time Setup (do once)
- [ ] **Push to GitHub** — Create a private repo on GitHub and push. `git remote add origin https://github.com/yourname/autospotter.git && git push -u origin main`
- [ ] **Generate release signing keystore** — See "Release signing keystore" task above. Store the keystore file and passwords somewhere safe (e.g. USB drive, password manager). If you lose it, you can never update the app.
- [ ] **Add release SHA-1 to Firebase** — Add the release keystore's SHA-1 fingerprint in Firebase Console so Google Sign-In works in release builds.

### Every Release
1. [ ] **Bump version** in `pubspec.yaml` — Increment the version name and build number. Example: `1.0.0+1` → `1.1.0+2`. The build number (`+N`) must always go up; Play Console rejects duplicates.
2. [ ] **Commit changes** — `git add . && git commit -m "v1.1.0 - description of changes"`
3. [ ] **Push to GitHub** — `git push`
4. [ ] **Build release bundle** — `flutter build appbundle --release` (produces `build/app/outputs/bundle/release/app-release.aab`)
5. [ ] **Test on a real device** — Install the release build and verify camera, sign-in, Gemini, and valuation all work.
6. [ ] **Upload to Play Console** — Go to Google Play Console → your app → Production (or testing track) → "Create new release" → upload the `.aab` file.
7. [ ] **Fill in release notes** — Write "What's new" text for users (e.g. "Bug fixes and performance improvements" or specific feature notes).
8. [ ] **Submit for review** — Google reviews typically take a few hours to a few days.

### Version Numbering Guide
| Change type | Example | When to use |
|---|---|---|
| Major (`2.0.0`) | Complete redesign, breaking changes | Rare — major overhaul |
| Minor (`1.1.0`) | New feature (e.g. sharing, new screen) | Each feature release |
| Patch (`1.0.1`) | Bug fix, small tweak | Quick fixes between features |
| Build number (`+N`) | `+1`, `+2`, `+3`... | Must increment every Play Store upload |

---

## Uncompleted — Bulk Image Processing (Stripe + Cloud Run)

- [ ] **Stripe integration for bulk processing** — Integrate Stripe on the website for upfront payment before processing. Options: per-batch pricing (e.g. £X for N images), credit top-ups, or pay-per-scan. Use Stripe Checkout or Payment Intents. Only begin processing once payment is confirmed via Stripe webhook or redirect. This bypasses Google Play billing entirely (no 15-30% cut).
- [ ] **Bulk upload page on website** — Add a page (e.g. `/bulk.html`) where users can upload multiple car images at once. After Stripe payment is validated, each image is sent to the Cloud Run `POST /identify?includeValuation=true` endpoint directly. Results are displayed in a table as they complete and can be downloaded as CSV/Excel/JSON.
- [ ] **Progress UI for bulk uploads** — Show per-image progress (queued, processing, complete, failed) with results appearing in real-time. Allow retry on failed images. Show a summary at the end.
- [ ] **Pricing model** — Stripe's fixed 20p per transaction means single-scan sales at 30p are a loss. Enforce a minimum batch purchase (e.g. 10 scans for £3.00). At 30p/scan in a batch of 10+, estimated profit is ~18-19p/scan after Stripe (1.5% + 20p per transaction), AI API (~0.02p), and valuation API (~5-15p) costs. Consider volume tiers: 10 scans £3.00, 25 scans £7.00 (28p each), 50 scans £12.50 (25p each). Stripe fee is amortised across the batch so larger purchases yield better margins.
- [ ] **Link bulk upload from main site** — Add a nav link or CTA for "Bulk Processing" aimed at dealers and fleet managers who want to process many vehicles at once without using the mobile app.

## Uncompleted — Trader Export Feature

- [ ] **Export scanned data (Trader plan only)** — Allow Trader plan users to download their saved scan data in CSV, Excel (.xlsx), or JSON format. Should include all identification fields (make, model, year range, generation, trim, body style, colour, number plate) and valuation data (dealer, private, trade prices, mileage). Add an "Export" button to the Saved Scans screen (visible only for Trader users). Consider using the `csv` and `excel` (or `syncfusion_flutter_xlsio`) packages. Web dashboard should also offer export via a download button on the user's scans section.

## Uncompleted — Branding & Visual Assets

### App Icon & Splash
- [x] **Design custom app icon** — Replace the default Flutter icon with a branded AutoSpotter icon. Create a 512x512 master PNG and generate all Android densities (mdpi through xxxhdpi) using `flutter_launcher_icons`. This icon is also used for the Play Store listing.
- [x] **Adaptive icon for Android** — Create foreground and background layers for Android adaptive icons so it looks correct across different device manufacturers.
- [x] **Custom splash screen** — Replace the blank white launch screen with a branded AutoSpotter splash using `flutter_native_splash` or native Android splash config.
- [ ] **Replace web favicon** — Replace `web/favicon.png` and `web/icons/` with the AutoSpotter brand icon.
  - *Image needed:* The app icon (already generated at `assets/icon/icon.png`) — no new image required, just needs deploying.

### Google Play Store Listing Assets
- [ ] **Feature graphic** (1024x500 PNG/JPG) — Banner displayed at the top of the Play Store listing. First thing users see. Should show brand name, tagline, and a visual of the app in action.
  - *Image needed:* 1024x500 banner with the AutoSpotter logo on the left, tagline "Instant AI Car Identification" in the centre, and a phone mockup showing the results screen on the right. Blue gradient background matching app theme (#1565C0).
- [ ] **Screenshots** (min 4, phone + optional tablet) — Real app screenshots showing: camera viewfinder, AI identification result, valuation card, and login/terms screen. Blur any real number plates in screenshots.
  - *Image needed:* 4+ real screenshots captured from the app on a phone. (1) Camera viewfinder with a car in frame, (2) AI identification results screen, (3) Valuation card with prices, (4) Login/terms screen. Blur any visible number plates.
- [ ] **Short description** (max 80 chars) — Concise tagline for Play Store, e.g. "Point your camera at any car for instant AI identification and UK valuation."
- [ ] **Full description** (max 4000 chars) — Detailed Play Store description covering features, how it works, and data usage.

### Website & Social Assets (Firebase Hosting)
- [ ] **AutoSpotter logo/brand mark** — Logo for the website header, privacy policy page, account deletion page, and admin dashboard. SVG + PNG versions.
  - *Image needed:* A clean wordmark or logo combining the car/reticle icon with "AutoSpotter" text. White-on-blue and dark-on-white variants. SVG preferred for scalability.
- [ ] **Open Graph image** (1200x630) — Social sharing preview image for when the site URL is shared on social media, WhatsApp, etc. Without this, shared links look blank.
  - *Image needed:* 1200x630 card with the AutoSpotter logo, tagline, and a visual of the app (e.g. phone mockup or car silhouette). Blue background. Text should be readable at thumbnail size.
- [ ] **Landing page hero image** — Phone mockup or illustration showing the app in action, for converting organic visitors into Play Store downloads.
  - *Image needed:* A phone frame/mockup containing a screenshot of the results screen (car identified with specs visible). Angled or floating style on a transparent or gradient background.

### In-App Illustrations
- [ ] **Empty state illustrations** — Custom illustrations for empty history, error screens, and "no result" states instead of plain icons and text.
  - *Images needed:* 3 simple line-art or flat illustrations (~300x300): (1) Empty history — a car with a clock or magnifying glass, (2) Error state — a car with a warning triangle, (3) No result — a car with a question mark. Use app theme colours (blue #1565C0, white, light grey).

## Uncompleted — Sharing, Reviews & Growth

### Sharing
- [ ] **Share identification result** — Add a "Share" button on the results screen that sends the car image + identification summary (make, model, year, price range) via the native share sheet (WhatsApp, Instagram, X, etc.). Free marketing with every share.
- [ ] **Share the app / Tell a friend** — Add a "Tell a friend" option (in about/settings screen) that shares the Play Store link with a short message like "I just identified a car with AutoSpotter! Try it out:".
- [ ] **Deep links** — Configure Firebase Dynamic Links or App Links so shared URLs open directly in the app if installed, or redirect to the Play Store if not.

### Reviews & Ratings
- [ ] **In-app review prompt** — After a successful identification (not on first use — e.g. after 3rd scan), prompt the user to rate the app using Google's in-app review API (`in_app_review` package). Keeps them in the app instead of navigating to the store.
- [ ] **Rate us button** — Add a persistent "Rate us on Google Play" link in the about/settings screen for users who want to leave a review in their own time.

### Social Proof & Presence
- [ ] **Link to social media accounts** — If social accounts are created (Instagram, X, TikTok), link to them from the about screen. Car content performs well on short-form video platforms.
- [ ] **User/scan count on login screen** — Display a subtle "Join X users identifying cars" message on the login screen to build trust and social proof. Pull the count from a Firestore aggregate or Cloud Function. Only enable once real user numbers are meaningful.

## Uncompleted — Professionalism & Quality of Life

- [x] **App version display** — Settings screen shows version from `package_info_plus`, plus version footer and about dialog.
- [x] **About / Contact screen** — Settings screen includes about dialog with version, copyright, contact email, plus links to privacy policy and terms.
- [x] **Link terms screen to hosted page** — Terms screen now links to the hosted privacy policy page instead of referencing a markdown file.
- [x] **User-friendly error messages** — Replaced all developer-oriented error messages (`$e.toString()`) with plain-English messages across login, camera, results, and settings screens.
- [x] **Offline / connectivity handling** — Camera screen checks connectivity before capture using `connectivity_plus`. Shows "No internet connection" snackbar if offline.
- [x] **Sign-out button** — Added settings screen accessible from camera screen with sign-out functionality and confirmation dialog.
- [x] **Haptic and sound feedback on capture** — Added `HapticFeedback.mediumImpact()` on capture button tap for tactile feedback.
- [x] **Accessibility / semantic labels** — Added semantic labels to capture button, processing overlay, history button, settings button (camera screen), and vehicle name and confidence indicator (results screen).
- [x] **Shimmer loading placeholder** — Replaced plain spinner with a pulsing shimmer skeleton placeholder while valuation loads. Uses `FadeTransition` with repeating animation.
- [x] **Consistent error styling** — Valuation errors now show in a styled error banner with icon, message, and retry button. Login and camera errors use user-friendly snackbar messages.

## Completed — UI Polish & Visual Improvements

### Results Screen
- [x] **Redesign valuation card** — Gradient card with shadow, hero price range, dealer/private/trade price tier grid, mileage row.
- [x] **Animated price reveal** — Fade + slide-up animation when prices load via `_AnimatedPrice` widget.
- [x] **Vehicle spec chips** — Colour, body style, generation, and trim displayed as Material chips with icons.
- [x] **Confidence indicator upgrade** — Custom circular arc gauge (`_ConfidenceGauge`) with colour-coded arc and percentage in centre.
- [x] **Image hero section** — Gradient overlay on captured image fading into the details section below.
- [x] **Number plate styled display** — UK-style yellow plate with bold text and border via `_UkPlate` widget.

### Camera Screen
- [x] **Processing overlay polish** — Pulsing car icon animation, stage-based status text ("Optimising image..." → "Asking AI to identify..."), indeterminate progress bar, dark overlay.
- [x] **Capture button animation** — White shutter flash overlay on capture with haptic feedback.
- [x] **Viewfinder overlay** — Rounded rectangle guide with "Align vehicle within frame" hint text.

### General
- [x] **Consistent theme and typography** — Refined Material 3 theme with custom seed colour, rounded card/chip/button shapes, centred app bar titles, and consistent spacing.
- [x] **Smooth page transitions** — Fade transition from camera to results screen with Hero widget on captured image.
- [x] **Empty and error states** — Polished "vehicle not recognised" state with orange car icon, helpful guidance text, and prominent retry button.

---

## Targeted Profit Analysis — Bulk Scans at 30p (Direct Cloud Run)

Cost assumptions: Stripe fee = 1.5% + 20p per transaction (UK cards). AI API ≈ £0.0002/scan. Valuation API ≈ £0.10/scan. Calling Cloud Run directly from our website.

### Full Accuracy (100% of images successfully scanned)

| Batch Size | Revenue | Stripe Fee | API Cost | Profit/Batch | Profit/Scan |
|---|---|---|---|---|---|
| 1 | £0.30 | £0.205 | £0.100 | **−£0.005** | −£0.005 |
| 5 | £1.50 | £0.223 | £0.501 | **£0.777** | £0.155 |
| 10 | £3.00 | £0.245 | £1.002 | **£1.753** | £0.175 |
| 25 | £7.50 | £0.313 | £2.505 | **£4.683** | £0.187 |
| 50 | £15.00 | £0.425 | £5.010 | **£9.565** | £0.191 |
| 100 | £30.00 | £0.650 | £10.020 | **£19.330** | £0.193 |

### Adjusted for ~90% Accuracy (10% failed/unusable images)

| Batch Size | Billable Scans | Revenue | Stripe Fee | API Cost (all attempts) | Profit/Batch | Profit/Billable Scan |
|---|---|---|---|---|---|---|
| 1 | 0.9 | £0.27 | £0.204 | £0.100 | **−£0.034** | −£0.038 |
| 5 | 4.5 | £1.35 | £0.220 | £0.501 | **£0.629** | £0.140 |
| 10 | 9 | £2.70 | £0.241 | £1.002 | **£1.458** | £0.162 |
| 25 | 22.5 | £6.75 | £0.301 | £2.505 | **£3.944** | £0.175 |
| 50 | 45 | £13.50 | £0.403 | £5.010 | **£8.088** | £0.180 |
| 100 | 90 | £27.00 | £0.605 | £10.020 | **£16.375** | £0.182 |

**Key takeaway:** Single-scan sales at 30p are a loss due to Stripe's 20p fixed fee. Enforce a minimum batch of 5–10 scans. At batch sizes of 10+, profit per scan stabilises around 16–19p. Larger batches amortise the Stripe fixed fee better. Consider volume tiers: 10 for £3.00, 25 for £7.00 (28p each), 50 for £12.50 (25p each) to incentivise bigger purchases while maintaining healthy margins.
