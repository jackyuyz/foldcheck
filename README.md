# FoldCheck: Foldable Inspector

A native iOS app for Apple's iPhone Duo that produces a timestamped PDF report with tamper-evident digital signatures for resale or insurance claims.

## Project Layout

```
foldcheck-ios/
├── project.yml                 # XcodeGen project configuration
├── App/                        # SwiftUI app (thin layer)
│   ├── Home/                   # Home screen
│   ├── Inspection/             # Inspection flow
│   ├── Summary/                # Results summary
│   ├── Report/                 # PDF report preview
│   ├── History/                # Session history
│   ├── Verify/                 # QR/PDF verification
│   ├── Paywall/                # StoreKit purchase
│   ├── Settings/               # App settings, language, FAQ
│   ├── Localization/           # In-app language (default English)
│   └── Resources/              # Assets, privacy manifest, permission strings
├── Packages/                   # Swift Packages (platform-independent)
│   ├── FoldKit/                # Fold state management
│   ├── HingeAnalysis/          # Hinge sweep analysis
│   ├── TestsKit/               # Test definitions & session model
│   ├── ReportKit/              # Report generation & signing
│   └── FoldL10n/               # UI and report copy (en, es, fr, ja, zh-Hans, zh-Hant)
├── Tests/                      # XCTest integration tests
├── UITests/                    # XCUITest UI tests
└── docs/
    ├── foldcheck-spec.md       # Full implementation spec
    └── ui/                     # Duo mockups (unfolded inner, partial, cover)
```

UI mockups in `docs/ui/png/` are drawn for iPhone Duo: a wide inner display with a center crease when fully open, two panels split by the hinge when partially open, and the outer cover when closed.

## Building on Mac

### Prerequisites

- **Xcode 27.1 RC** (`/Applications/Xcode-27.1RC.app`, build 27A9275) with the **iOS 27.1 iPhone Duo simulator**. The system-selected Xcode may be older; set `DEVELOPER_DIR` for commands below.
- [XcodeGen](https://github.com/yonaskolb/XcodeGen) (`brew install xcodegen`)
- Swift 6 (use the toolchain bundled with Xcode 27.1 RC)

### Build Steps

1. Clone the repository:
   ```bash
   git clone <repo-url>
   cd foldcheck-ios
   ```

2. Select the toolchain for this shell and generate the Xcode project:
   ```bash
   export DEVELOPER_DIR=/Applications/Xcode-27.1RC.app/Contents/Developer
   xcodegen generate
   ```

3. Open in Xcode:
   ```bash
   open FoldCheck.xcodeproj
   ```

4. Select the `FoldCheck` scheme and build (⌘B)

### Running Tests

**Swift Package tests (works on Linux and macOS):**
```bash
cd Packages/FoldKit && swift test
cd Packages/HingeAnalysis && swift test
cd Packages/TestsKit && swift test
cd Packages/ReportKit && swift test
cd Packages/FoldL10n && swift test
cd Packages/Library && swift test     # SwiftData: tests run on macOS; the module is empty on Linux
```

**App tests (requires Xcode):**
```bash
DEVELOPER_DIR=/Applications/Xcode-27.1RC.app/Contents/Developer xcodebuild test -scheme FoldCheck -destination 'platform=iOS Simulator,name=iPhone Duo' -parallel-testing-enabled NO
```

### Mock Hinge for Testing

Use launch arguments to mock fold states:

```bash
# In Xcode: Edit Scheme → Run → Arguments
-UITestMode 1 -FoldMock open        # Fully open
-UITestMode 1 -FoldMock closed      # Closed
-UITestMode 1 -FoldMock half:90     # Partially open at 90°
-UITestMode 1 -FoldMock sweep:10-180:6   # Animated sweep
-UITestMode 1 -FoldMock script:gappy     # Bundled script: App/Resources/MockScripts/gappy.json
-UITestMode 1 -FoldMock script:jumpy     # Bundled script with backwards jumps
-FoldDebugOverlay 1                 # Debug overlay; tap it for fold.closed/half/open/nohinge/sweep
-ResetFoldCounter 1                 # Clear the saved fold counter totals at launch
```

Or use the `FoldCheck-MockHinge` scheme which has mock arguments preconfigured.

The hinge test (T4) replays a `sweep:`/`script:` mock each time a sweep step starts, as if the
user moved the hinge when asked. With a static mock (`open`, `closed`) it ends Unavailable.

## Architecture

### Swift Packages (Platform-Independent)

All business logic is in Swift Packages that build and test on Linux:

- **FoldKit**: Core fold state primitives (`FoldState`, `FoldPosture`, `FoldStateProvider` protocol, `MockFoldStateProvider` for testing, `RelativeAngleTracker`, `DuoDisplaySpec`)
- **HingeAnalysis**: Hinge sweep analysis (`HingeSample`, `HingeSweepAnalyzer`, `HingeSweepReport` with quality assessment)
- **TestsKit**: Test definitions (`TestID`, `TestOutcome`, `TestResult`, `InspectionSession`, `FoldCounter`)
- **ReportKit**: Report generation (`CanonicalReport`, `ReportEnvelope`, `ReportSigner` protocol, PDF content assembly, device names)
- **Library**: Saved sessions (`StoredSession` SwiftData model holding the encoded `InspectionSession`, `SessionLibrary` save/delete/query, latest result per test). Apple platforms only; empty on Linux
- **FoldL10n**: String catalogs and `AppLanguage`. English is the default. Spanish, French, Japanese, Simplified Chinese, and Traditional Chinese are selected in Settings.

### App Layer (iOS-Only)

The SwiftUI app is a thin layer that:
- Bridges to system APIs (hinge via `onHingeChange`, cameras, sensors)
- Provides UI for the inspection flow
- Handles StoreKit purchases
- Renders PDFs (PDFKit)
- Manages local persistence (SwiftData): sessions live in `Application Support/Sessions.store` on the device, with no CloudKit and nothing uploaded. Full inspections save on their own; quick tests save with "Save to History"

## Unverified/Assumed APIs

The following APIs are marked as unverified in the spec and wrapped in protocols with mocks:

| API | Status | Fallback |
|-----|--------|----------|
| `View.onHingeChange(isEnabled:_:)` | **Verified in Xcode 27.1 RC Duo simulator** | Mock provider for tests |
| `UIHingeInteraction` | **Confirmed** but untested | Protocol wrapper |
| Hinge angle range/precision | **Undocumented** | Relative tracking, no absolute thresholds |
| Background hinge events | **Not available** | Count only in foreground |
| `UIScreen.brightness` per display | **Unverified** | Query per-scene |
| Proximity sensor on Duo | **Unverified** | Skip if unavailable |

## Duo displays

`DuoDisplaySpec` in FoldKit is the only place these numbers live. They come from public reporting and are not confirmed in Apple's documentation.

| Panel | Diagonal | Pixels | Orientation | Ratio |
|-------|----------|--------|-------------|-------|
| Outer (cover) | 5.4" | 1398 × 2034 | Portrait | ~1:1.455 |
| Inner (unfolded) | 7.6" | 2670 × 1878 | Landscape | ~1.42:1 |

Crease width, point sizes, and `UIScreen.scale` are still unknown. They are `nil` on `DuoDisplaySpec.Assumption`. Do not invent them by dividing the pixel sizes by 2 or 3.

## Open Questions for Product Manager

1. **Hinge thresholds**: Spec AC2. A gap of 15° or more, including 25°, is Attention. No hinge data is Unavailable, never Fail.

2. **Crease rating scale**: Is 1-5 sufficient? Should we provide reference images for each rating?

3. **Report language**: Resolved. The app UI defaults to English and can be switched in Settings. PDF language can match the app or stay English for resale.

4. **Touch grid density**: Current spec says ~7mm cells with ½ size near crease. Need real-device testing to calibrate.

5. **Multi-cam test combinations**: Which specific camera combinations should we test on Duo?

6. **Fold counter display**: How prominently should we show the "folds observed while app running" disclaimer?

7. **Pricing validation**: Is $2.99 one-time still the right price point?

## Test Results (M7)

Swift Package tests passed on macOS using Xcode 27.1 RC (258 total):

| Package | Tests | Status |
|---------|-------|--------|
| FoldKit | 46 | ✅ Pass |
| HingeAnalysis | 37 | ✅ Pass |
| TestsKit | 112 | ✅ Pass |
| ReportKit | 41 | ✅ Pass |
| FoldL10n | 10 | ✅ Pass |
| Library | 6 | ✅ Pass |
| Store | 6 | ✅ Pass |

## Implemented Milestones

### M1: Skeleton ✅
- FoldKit package with fold state management
- HingeAnalysis package with sweep analysis
- TestsKit package with test definitions
- ReportKit package with signing/verification
- XcodeGen project structure
- SwiftUI app shell with navigation

### M2: Display & touch tests ✅
- T1 touch grid: ~7 mm cells, half-size cells within ±10 mm of the crease on the Duo inner display, multi-touch count, misses shown in red (AC3 covered by a scripted UI test)
- T2 pixels: six solid colors at full brightness; tapped spots stored as normalized points
- T3 crease visibility: 1–5 rating at three guided viewing angles, optional imported photo
- Logic in TestsKit (`TouchGridLayout`, `TouchGridSession`, `PixelTestSession`, `CreaseVisibilitySession`, `InspectionPlan`); screens in `App/Tests/`
- The cell size assumes iPhone-like density (~6 pt/mm) and the crease at the center; both need checking on a real Duo (`reservedRegions(.division)`)

### M3: Hinge test & fold counter ✅
- T4 hinge sweep: two guided "close to ~20°, open to flat" sweeps plus a 5 s hold at ~90°, live speed meter ("Too fast, go slower"), Swift Charts plot; a slider gives the same analysis without a hinge (flagged in the result)
- HingeAnalysis judges continuity, not absolute angles: gaps, direction legs, backwards jumps, readings per 10°, hold jitter/drift (AC2: clean → Pass, 25° gap → Attention, jumps → Attention, no data → Unavailable with retry)
- F5 fold counter: closed→open cycles and time per display, debounced, counted only while FoldCheck is in the foreground, shown as "Folds observed by FoldCheck"; all-time totals saved locally (AC7)
- The real hinge bridge (`onHingeChange`) compiles only with the iOS 27.1+ SDK (`FOLDCHECK_HINGE_API`, set in project.yml) and runs only on iOS 27.1+

### M4: Hardware tests ✅
- T5 cameras: every camera from `AVCaptureDevice.DiscoverySession` is previewed in turn; Capture keeps only brightness and sharpness from a downsampled luma frame (no image stored) and the user says whether the picture looks right. No frame → Fail; no cameras (the simulator) → Unavailable
- T6 audio: a generated tone in the left channel, then the right, then a 3 s recording with a level meter played back; each confirmed by the user. The recording is a temporary file deleted when the test ends
- T7 Touch ID: one `LAContext` match. Only planned on devices that report Touch ID, so Face ID iPhones show it as Not applicable and no Face ID usage string is needed. Not enrolled or locked out → Attention; no match → Fail
- T8 sensors and haptics: accelerometer (≈1 g) and gyroscope (a visible turn) over 4 s, the proximity sensor, and three haptic taps the user confirms. Parts the device doesn't offer are Unavailable, never Fail
- T9 buttons: volume up and down detected through `AVAudioSession.outputVolume`; the side button, Action button and Camera Control can't be observed, so the user checks them off
- Camera or microphone access off → that test is Skipped with the reason and a Settings link (AC6)
- Pass/Attention/Fail rules live in TestsKit (`CameraTestSession`, `AudioTestSession`, `BiometricCheck`, `SensorsTestSession`, `ButtonsTestSession`); screens in `App/Tests/Hardware/`
- Audio, Touch ID matches and real camera frames need a device; the simulator UI tests cover the no-camera, no-sensor and buttons paths

### M5: Reports ✅
- F2 PDF (`ReportPDFRenderer`, US Letter): device model, OS, storage, date and time zone, summary, every result with its metrics and notes, the hinge chart, attached crease photos, the signature with a QR code, and the disclaimer. Saved in `Application Support/Reports` and shared from the preview
- F3 signing: a per-install P-256 key created in the Secure Enclave on first use; the Keychain keeps only its encrypted `dataRepresentation` (this device only). Without a Secure Enclave the development software key signs and the report says "Development build (unsigned)". The Apple silicon simulator has a Secure Enclave, so simulator reports are signed for real
- The PDF's Subject carries a `ReportBundle`: the exact signed canonical-JSON bytes plus the envelope. `ReportVerifier` hashes those bytes, so any changed byte fails (AC4)
- Verify: importing a PDF checks content and signature and lists the signed results to compare with the pages; scanning the QR (VisionKit) checks the signature only. Both say whether this installation or another one (key fingerprint) signed it
- Reports are unlocked in DEBUG builds until StoreKit lands in M6; release builds show the paywall
- Not checked yet: importing through the Files picker on a device, and QR scanning (needs a camera)

### M6: History, reminders, Store ✅
- `Store` package (StoreKit 2): `com.jackyu.foldcheck.reports`, one-time purchase. Loads the product, listens to `Transaction.updates` from launch, recomputes the unlock from `currentEntitlements` (unverified grants nothing, a refund locks again), handles pending approval and restore, and caches the unlock only to avoid a paywall flash
- Paywall shows the App Store price (`displayPrice`, never hardcoded) with loading, unavailable, pending, and failed states, and closes once unlocked; terms link to Apple's standard EULA
- AC8 gating: every test is free; PDF reports, History and compare, monthly reminders and the fold stats page need the purchase. Inspections are still saved for free users, behind a lock, so buying shows them all. `-UnlockReports` (DEBUG only) unlocks for UI tests
- F4: tapping a saved inspection opens its summary; Compare shows two inspections side by side with each test's outcome and the metrics that show wear (touch misses, crease rating, hinge continuity and gap, pixel issues, score), marked better, worse or unchanged (`SessionComparison` in TestsKit)
- F6: a monthly local notification on the same day (capped at 28) at 10:00, in the app language; denied permission turns the toggle back off and says where to fix it
- `Configuration.storekit` is selected in the Run scheme. `SKTestSession` tests cover purchase, refund, Ask to Buy, failure and restore. All five passed in the locally signed Xcode 27.1 RC command-line run on this host. They skip if the local StoreKit environment cannot load products; device/Sandbox validation still needs the owner's development team
- Before submission: replace the placeholder privacy policy URL (`AppLinks.privacy`) and enable Family Sharing for the product in App Store Connect

### M7: Polish ✅
- Adaptive Home, test introductions and Summary: `ArrangementView` panels following the actual reserved fold region in either orientation (outside scroll views), a single reading column on the cover; wide panels scroll independently at accessibility text sizes. `reservedRegions(.division, .includeInactive)` is observed across layout changes; layout follows geometry, not hinge angles. The hinge gauge uses the system navigation toolbar to avoid covering the cover-screen rail.
- Accessibility: optional physical single-cell tapping in T1 (Settings or the test introduction); VoiceOver direct-touch guidance; visual tests can be skipped with a recorded “needs sighted help” reason. No synthetic touches or automatic Pass results.
- Scrollable test introductions, larger canvas controls, localized control labels, semantic result colors, and Reduce Motion support for app animations. The Home last-inspection action now opens the real summary behind the purchase gate. Developer settings are DEBUG-only.
- Nine new strings translated into all six catalogs; format-placeholder parity checks; English and Simplified Chinese PDF rendering and interaction coverage (AC10).
- Actual Duo review screenshots and bilingual sample PDF pages are generated by `PolishUITests` and `ReportPDFTests` using DEBUG-only, isolated in-memory sample sessions (`-ScreenshotFixtures`). No real inspection history is changed.
- Review notes, repeatable verification steps and remaining device/submission checks: [docs/review/m7-validation.md](docs/review/m7-validation.md) and [docs/review/app-review-notes.md](docs/review/app-review-notes.md).
- Simulator coverage does not replace physical hinge/touch calibration, human VoiceOver testing or App Store Connect configuration.


## Languages

FoldCheck opens in **English**. Settings → Language switches the interface among:

| Code | Name in the picker |
|------|--------------------|
| `en` | English (default) |
| `es` | Español |
| `fr` | Français |
| `ja` | 日本語 |
| `zh-Hans` | 简体中文 |
| `zh-Hant` | 繁體中文 |

The choice is stored on the device (`foldcheck.appLanguage`). It does not follow the iPhone language, so a Chinese phone can still show an English app. Camera and microphone system prompts use `InfoPlist.strings` and still follow the iPhone language.

**Report language** is separate. “Match app language” writes the PDF in the UI language. “English (for resale)” keeps the PDF in English. `ReportContentAssembler.assemble(session:envelope:language:)` defaults to English.

## License

Proprietary - All rights reserved.
