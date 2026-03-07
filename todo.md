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

## Completed — REST API for RapidAPI

- [x] **Car Detector REST API** — Standalone Dart server in `api/` directory exposing the car identification pipeline as a REST API. `POST /identify` accepts multipart image upload, runs image optimisation + Gemini 2.5 Flash identification, and returns JSON. Query param `includeValuation=true` auto-fetches UK valuation data when a plate is detected. `GET /health` for Cloud Run health checks.
- [x] **RapidAPI Auth Middleware** — Validates `X-RapidAPI-Proxy-Secret` header. Open/dev mode when env var is unset. `/health` always bypasses auth.
- [x] **Server-Side Gemini Integration** — Rewrote `gemini_service.dart` to use `google_generative_ai` (server-side SDK) with `DataPart` instead of `firebase_ai`'s `InlineDataPart`. Same schema, prompt, and temperature as Flutter app.
- [x] **Concurrent-Safe Image Processing** — Adapted `image_processor.dart` with unique temp file suffixes to avoid collisions under concurrent requests. Removed `cropToVehicle()` (depends on `dart:ui`).
- [x] **Docker + Cloud Run Ready** — 2-stage AOT Dockerfile (dart:3.3 build → dart:3.3-slim runtime). Non-root user. Configurable via `GEMINI_API_KEY`, `UKVD_API_KEY`, `RAPIDAPI_PROXY_SECRET`, `PORT` env vars.
- [x] **OpenAPI 3.0 Spec** — Full `openapi.yaml` documenting both endpoints, request/response schemas, and RapidAPI security scheme.

## Uncompleted — Other Features

- [x] **Price Estimation** — Get price estimates via UK Vehicle Data API using the number plate. Button on results screen fetches retail/trade/private valuations with loading spinner and error handling. Requires a valid API key in `constants.dart`. Sandbox mode limited to VRMs containing "A".
- [ ] **Identification History** — Track past identifications. History button exists in camera UI and storage dependency included but not functional.
- [ ] **Manual Edit/Correction** — Allow users to override AI results with manual search and correction. Button present but unconnected.
- [ ] **Gallery Upload** — Identify cars from existing photos. `image_picker` dependency included but not integrated into the UI.
- [ ] **Extended Vehicle Support** — Full identification support for vans, trucks, and motorcycles (currently marked "coming soon").
- [x] **User Accounts — Google Sign-In** — Google Sign-In with Firebase Auth and Firestore user profiles. Auth gate in main.dart routes unauthenticated users to login screen.
- [ ] **Scan History Persistence in Firestore** — Save past identifications to Firestore under each user's account.
- [ ] **Favourites / Bookmarking** — Allow users to bookmark/favourite car identifications.
- [ ] **Sign-Out Button on Camera Screen** — Add a sign-out option accessible from the camera screen.
