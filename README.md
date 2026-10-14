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

- Xcode 15.0+ with iOS 17.0+ SDK
- [XcodeGen](https://github.com/yonaskolb/XcodeGen) (`brew install xcodegen`)
- Swift 6.0+ (included with Xcode 16+)

### Build Steps

1. Clone the repository:
   ```bash
   git clone <repo-url>
   cd foldcheck-ios
   ```

2. Generate the Xcode project:
   ```bash
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
```

**App tests (requires Xcode):**
```bash
xcodebuild test -scheme FoldCheck -destination 'platform=iOS Simulator,name=iPhone 17 Pro'
```

### Mock Hinge for Testing

Use launch arguments to mock fold states:

```bash
# In Xcode: Edit Scheme → Run → Arguments
-UITestMode 1 -FoldMock open        # Fully open
-UITestMode 1 -FoldMock closed      # Closed
-UITestMode 1 -FoldMock half:90     # Partially open at 90°
-UITestMode 1 -FoldMock sweep:10-180:6   # Animated sweep
-FoldDebugOverlay 1                 # Show debug overlay
```

Or use the `FoldCheck-MockHinge` scheme which has mock arguments preconfigured.

## Architecture

### Swift Packages (Platform-Independent)

All business logic is in Swift Packages that build and test on Linux:

- **FoldKit**: Core fold state primitives (`FoldState`, `FoldPosture`, `FoldStateProvider` protocol, `MockFoldStateProvider` for testing, `RelativeAngleTracker`, `DuoDisplaySpec`)
- **HingeAnalysis**: Hinge sweep analysis (`HingeSample`, `HingeSweepAnalyzer`, `HingeSweepReport` with quality assessment)
- **TestsKit**: Test definitions (`TestID`, `TestOutcome`, `TestResult`, `InspectionSession`, `FoldCounter`)
- **ReportKit**: Report generation (`CanonicalReport`, `ReportEnvelope`, `ReportSigner` protocol, PDF content assembly, device names)
- **FoldL10n**: String catalogs and `AppLanguage`. English is the default. Spanish, French, Japanese, Simplified Chinese, and Traditional Chinese are selected in Settings.

### App Layer (iOS-Only)

The SwiftUI app is a thin layer that:
- Bridges to system APIs (hinge via `onHingeChange`, cameras, sensors)
- Provides UI for the inspection flow
- Handles StoreKit purchases
- Renders PDFs (PDFKit)
- Manages local persistence (SwiftData)

## Unverified/Assumed APIs

The following APIs are marked as unverified in the spec and wrapped in protocols with mocks:

| API | Status | Fallback |
|-----|--------|----------|
| `View.onHingeChange(isEnabled:_:)` | **Confirmed** but untested | Mock provider for tests |
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

1. **Hinge thresholds**: What gap size (degrees) should trigger "Attention" vs "Fail"? Currently: 15° = Attention, 25° = Fail.

2. **Crease rating scale**: Is 1-5 sufficient? Should we provide reference images for each rating?

3. **Report language**: Resolved. The app UI defaults to English and can be switched in Settings. PDF language can match the app or stay English for resale.

4. **Touch grid density**: Current spec says ~7mm cells with ½ size near crease. Need real-device testing to calibrate.

5. **Multi-cam test combinations**: Which specific camera combinations should we test on Duo?

6. **Fold counter display**: How prominently should we show the "folds observed while app running" disclaimer?

7. **Pricing validation**: Is $2.99 one-time still the right price point?

## Test Results (Linux)

Unit tests pass on Linux:

| Package | Tests | Status |
|---------|-------|--------|
| FoldKit | 38 | ✅ Pass |
| HingeAnalysis | 21 | ✅ Pass |
| TestsKit | 36 | ✅ Pass |
| ReportKit | 34 | ✅ Pass |
| FoldL10n | 8 | ✅ Pass |

## Implemented Milestones

### M1: Skeleton ✅
- FoldKit package with fold state management
- HingeAnalysis package with sweep analysis
- TestsKit package with test definitions
- ReportKit package with signing/verification
- XcodeGen project structure
- SwiftUI app shell with navigation

### M2-M7: Pending
- Display & touch tests (M2)
- Hinge test & fold counter (M3)
- Hardware tests (M4)
- PDF reports with signing (M5)
- History, reminders, Store (M6)
- Polish (M7). In-app language switching is in place; remaining work is visual polish.

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
