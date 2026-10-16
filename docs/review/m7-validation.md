# M7 validation

M7 is developed directly on `main`. Toolchain: Xcode 27.1 RC (27A9275), `/Applications/Xcode-27.1RC.app`; Duo simulator: iOS 27.1. The default `xcode-select` can point to another Xcode. Use an explicit `DEVELOPER_DIR`; do not change the machine-wide selection.

## Repeatable checks

```bash
export DEVELOPER_DIR=/Applications/Xcode-27.1RC.app/Contents/Developer
xcodebuild -version
xcodegen generate
xcrun simctl list devices available
xcodebuild test -project FoldCheck.xcodeproj -scheme FoldCheck \
  -destination 'platform=iOS Simulator,name=iPhone Duo' \
  -parallel-testing-enabled NO -collect-test-diagnostics never -resultBundlePath /tmp/foldcheck-m7-review.xcresult \
  -only-testing:FoldCheckTests -only-testing:FoldCheckUITests/PolishUITests \
  -only-testing:FoldCheckUITests/ReportUITests -only-testing:FoldCheckUITests/StoreUITests
```

Choose a new result-bundle path for each run. Do not delete existing results to rerun. Use a configured development team to exercise StoreKit tests; local command-line installations can skip those tests.

Package checks: run `swift test --package-path Packages/<name>` for FoldKit, HingeAnalysis, TestsKit, ReportKit, FoldL10n, Library and Store with the same toolchain. The catalogs check key completeness and format placeholder types in all six languages.

`PolishUITests` exercises separate-contact touch input, a recorded Chinese sighted-help skip, the largest accessibility text size, and captures Home, Summary, report, compare, touch grid and a sampled hinge curve in English and Simplified Chinese. `ReportPDFTests.testM7BilingualReportPagesForVisualReview` checks all result names and signature/disclaimer content, then attaches every rendered page and the PDF in both languages. Inspect the images as well as extracted text.

```bash
xcrun xcresulttool export attachments --path /tmp/foldcheck-m7-review.xcresult \
  --output-path /tmp/foldcheck-m7-review-attachments
```

Fixtures are gated by DEBUG and `-ScreenshotFixtures`. They use a separate in-memory SwiftData container and explicit “Sample data / 示例数据” notes. Normal app history is never cleared or seeded. Mock fold signals do not resize the simulator: use Xcode 27.1 RC Device Hub's Open / Partially Open / Closed controls for actual posture validation.

## Acceptance and remaining manual checks

- AC10: English and Simplified Chinese catalogs are complete; both languages must render all results, a disclaimer and signature/QR in the PDF. UI language and report language remain independent.
- Verify light/dark appearance, regular and accessibility text, and Open / Partially Open / Closed in Device Hub. On the inner screen, ArrangementView owns the two scroll panels and chooses the split axis from the actual reserved fold region, including a horizontal division in portrait. The observer includes inactive regions and rechecks after the first layout pass. The hinge gauge uses a system toolbar item rather than overlaying the navigation rail. The cover uses a single scroll column and accessibility text scrolls within each wide panel; no layout decisions depend on hinge angle.
- With VoiceOver enabled, check introduction reading order, direct touch guidance, all canvas controls, sighted-help skip, outcome labels and comparison arrows. Test actual screen-reader gestures with a human, not only accessibility identifiers.
- With Reduce Motion enabled, inspect inspection transitions, history selection, FAQ expansion, hinge gauge and microphone meter. App animations use the system preference; live values still update.
- On physical Duo: check touch target scale and crease band, hinge sampling/calibration, real camera discovery, per-display brightness restoration, Touch ID, audio routing, proximity, buttons and haptics.
- Run a first-time inspection with a person and time it (AC1: at most six minutes). Check permissions, notification delivery, no inspection-data network traffic (AC9), Files import and camera QR scanning.
- Resolve the submission items in `app-review-notes.md` before upload. M7 simulator completion does not imply these external/device checks passed.

## Recorded run

Package tests on Xcode 27.1 RC: **256 passed** (FoldKit 46, HingeAnalysis 37, TestsKit 110, ReportKit 41, FoldL10n 10, Library 6, Store 6). All six catalogs also passed after the final signing-copy changes.

The final Release simulator build passed. The app/PDF tests include actual StoreKit product loading, purchase/refund, Ask to Buy, failure and restore on this host. StoreKit fixtures now clear their test transactions after each test and wait for revocation propagation, avoiding state leaking into free-user UI checks.

Bilingual QA PDFs and all four rendered pages are in `reports/`. They were inspected visually: Chinese glyphs, headings, metrics, QR, signing scope and disclaimer render without overlap. These use the explicitly labeled development software signer.

The native Duo uses a side navigation rail rather than a classic TabBar. UI queries support both. Duo also exposes multiple screens: capture `XCUIScreen.screens`, not just `.main`, and use Device Hub / `simctl io <device> enumerate` to identify the active display when reviewing screenshots. The simulator's app-level frame can describe the cover while a visible window is on the inner display; accessibility assertions exercise the actual controls rather than inferring their layout from that frame.

Do not set `CODE_SIGNING_ALLOWED=NO` for PDF UI verification: this removes the simulated Keychain entitlements and report generation fails with OSStatus -34018. A normal local simulator build (`CODE_SIGN_IDENTITY=-`) preserves simulated entitlements. A physical device or App Store distribution still needs the owner's development team.

Native posture review also checked Closed, Partially Open, Open and rotation in Device Hub. Portrait uses a horizontal division (top/bottom panels), landscape uses a vertical division (left/right panels). The gauge was moved into the system toolbar after the original overlay covered the short cover-screen navigation rail. Dark appearance review led to separate high-contrast accent and filled-button colors; the simulator was restored to its original light appearance.

The final source passed **33 distinct app/UI scenarios**: 16 app tests, 12 Duo UI tests (including five M7 cases), and five ordinary-iPhone display/inspection regressions (including touch rotation). The full ordinary-iPhone run passed four; the two layout/input cases were rerun after the posture update and passed again.

Local result bundles (2026-10-16):

| Evidence | Result / path |
|---|---|
| Duo broad run | `/tmp/foldcheck-m7-complete.xcresult`: 27 passed; the new toolbar handoff case exposed a popover-dismissal race |
| Final handoff fix + app regressions | `/tmp/foldcheck-m7-gauge-final.xcresult`: 17/17 passed, including the formerly failing toolbar case |
| Ordinary iPhone, four cases | `/tmp/foldcheck-m7-fallback.xcresult`: 4/4 passed |
| Ordinary iPhone after posture update | `/tmp/foldcheck-m7-fallback-final.xcresult`: 2/2 passed |
| Final Release | `/tmp/foldcheck-m7-final-release.log`: BUILD SUCCEEDED |

The handoff now waits until the popover disappears before presenting the inspection, with no fixed timing delay. No known failing checks remain in the covered scenarios. The bundles above are temporary local evidence; durable selected captures and the gallery are committed-ready under `docs/review/`.

The 12 bilingual UI captures, largest-text capture and four rendered PDF pages were visually reviewed. Native cover and partial-posture captures supplement the mock-driven screenshots. Dark appearance was recaptured after the adaptive accent fix. See `README.md` in this directory for the gallery.

## Touch rotation regression (2026-10-16)

The live Touch Test now resolves the crease from `reservedRegions(kind: .division, options: .includeInactive)` in canvas coordinates, including its axis and normalized center. Until a region is available, portrait Duo canvases use a horizontal crease and landscape canvases a vertical one. The touch test allows rotation. A changed canvas or fold layout clears coverage and any stale missed-cell decision; equal geometry preserves coverage. The final orientation is still recorded in the result.

- TestsKit: 110/110 passed in `/tmp/foldcheck-touch-rotation-package.log`. New regressions verify full touch coverage in both axes and that a changed system division updates the band and clears old cell IDs even without a resize.
- Native Duo tap-only input: passed in `/tmp/foldcheck-touch-rotation.xcresult`.
- Single-screen iPhone rotation: passed in `/tmp/foldcheck-touch-rotation-fallback.xcresult` across landscape left, portrait and landscape right, checking that each rotation resets coverage and new input still registers.
- Native Duo: Device Hub Rotate Right verified portrait → landscape → portrait with the real hinge provider, horizontal → vertical → horizontal band, and coverage resetting from 1 to 0. Captures are `screenshots/en-touch-portrait.png` and `screenshots/en-touch-landscape.png`.

The first two native automated rotation attempts failed because `XCUIDevice.orientation` did not rotate the inner panel in this RC (its canvas remained 669 × 951). The final regression explicitly skips multi-screen simulators and runs on the ordinary iPhone with FoldMock; native rotation uses Device Hub. This is a limitation of this automation path, not a claimed native automated pass.

The final Release simulator build after the rotation fix passed: `/tmp/foldcheck-touch-rotation-release.log` (`BUILD SUCCEEDED`).
