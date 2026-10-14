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
│   ├── Settings/               # App settings & FAQ
│   └── Resources/              # Assets, privacy manifest
├── Packages/                   # Swift Packages (platform-independent)
│   ├── FoldKit/                # Fold state management
│   ├── HingeAnalysis/          # Hinge sweep analysis
│   ├── TestsKit/               # Test definitions & session model
│   └── ReportKit/              # Report generation & signing
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
```

**App tests (requires Xcode):**
```bash
xcodebuild test -scheme FoldCheck -destination 'platform=iOS Simulator,name=iPhone 16'
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

- **FoldKit**: Core fold state primitives (`FoldState`, `FoldPosture`, `FoldStateProvider` protocol, `MockFoldStateProvider` for testing, `RelativeAngleTracker`)
- **HingeAnalysis**: Hinge sweep analysis (`HingeSample`, `HingeSweepAnalyzer`, `HingeSweepReport` with quality assessment)
- **TestsKit**: Test definitions (`TestID`, `TestOutcome`, `TestResult`, `InspectionSession`, `FoldCounter`)
- **ReportKit**: Report generation (`CanonicalReport`, `ReportEnvelope`, `ReportSigner` protocol, PDF content assembly, device names)

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

## Open Questions for Product Manager

1. **Hinge thresholds**: What gap size (degrees) should trigger "Attention" vs "Fail"? Currently: 15° = Attention, 25° = Fail.

2. **Crease rating scale**: Is 1-5 sufficient? Should we provide reference images for each rating?

3. **Report language**: Should users be able to generate reports in English even if their device is in Chinese (for international resale)?

4. **Touch grid density**: Current spec says ~7mm cells with ½ size near crease. Need real-device testing to calibrate.

5. **Multi-cam test combinations**: Which specific camera combinations should we test on Duo?

6. **Fold counter display**: How prominently should we show the "folds observed while app running" disclaimer?

7. **Pricing validation**: Is $2.99 one-time still the right price point?

## Test Results (Linux)

All 125 unit tests pass on Linux:

| Package | Tests | Status |
|---------|-------|--------|
| FoldKit | 35 | ✅ Pass |
| HingeAnalysis | 21 | ✅ Pass |
| TestsKit | 36 | ✅ Pass |
| ReportKit | 33 | ✅ Pass |

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
- Polish & localization (M7)

## License

Proprietary - All rights reserved.
