# FoldCheck: Implementation Spec (iOS)

> **Instructions for the coding agent**
> 1. Read this whole spec before writing any code, including §3 (fold-state matrix), §7 (edge cases), §8 (tests and acceptance criteria) and §11 (assumptions).
> 2. Implement strictly in the milestone order in §10. Finish each milestone's tests before starting the next one, and keep `main` buildable at every step.
> 3. Keep everything local and on-device: no backend, no server, no database beyond local files / SwiftData / UserDefaults, no login, no analytics or ad SDKs, no third-party networking.
> 4. Write unit tests alongside each module (not at the end). UI tests drive the app through the mockable `FoldStateProvider` and launch arguments described in §8.
> 5. Any API marked **UNCONFIRMED** in this spec must be wrapped in a runtime capability check with the fallback described next to it. Never call it unguarded, and never "fix" a compile error by inventing a different API name: stop and leave a `// TODO(verify-api):` note instead.
> 6. Use the hinge only for interactions and effects. Use size classes, `ArrangementView`, and reserved regions for layout (Apple's guidance).
> 7. Do not add a backend, login, cloud sync service, or remote config. If something seems to need one, stop and add it to §11 as an open question.

## 0. Header

| Field | Value |
|---|---|
| Project codename | **FoldCheck** (Notion: "FoldCheck"; Reddit doc #12 "折叠机体检与二手/保险报告") |
| Official App Store name | **FoldCheck: Foldable Inspector** (30 chars) |
| Subtitle | **Hinge, crease & screen tests** (29 chars) |
| Name check (US App Store, 2026-10-13) | No app named "FoldCheck". Generic phone-diagnostics apps exist (e.g., "Phone Doctor Plus", "TestM"-style). Fallback: "DuoCheck: Hinge & Screen Test". |
| Recommended repo | `foldcheck-ios` |
| Bundle ID | `com.jackyu.foldcheck` |
| Platform / min OS | iOS, iPhone only, **min iOS 27.0** (hinge tests need iPhone Duo; screen/touch/camera/audio tests run on any iPhone) |
| Priority | **Low** |
| Target | ≈2 weeks |
| **Overlap note** | Partly overlaps **HingeLab** (the Reddit doc called it "HingeLab 铰链仪器"; both read continuous hinge angles) and the ideas doc's **HingeTools** protractor (4.14). FoldCheck's distinct angle is the **resale / insurance / AppleCare-claim report**. Share `FoldKit` + `HingeInput` packages with HingeLab/FoldPlay; don't duplicate the instrument features. A simple angle meter is included only as part of the hinge test. |

**Platform API status (checked 2026-10-13, ET).** Sources: Apple tech talks 111463 / 111464 / 111465 on developer.apple.com/videos (transcript summaries at wwdc.ai), Apple's "Prepare your app for iPhone Duo" page (developer.apple.com/iphone-duo/prepare/), Apple doc content for `UIHingeInteraction` and `onHingeChange` (developer.apple.com pages render with JavaScript, so their text was read through a doc mirror and the tech talks), and the Apple-engineer answers in the Sept 23–24 iPhone Duo Photos & Camera forum Q&A.

| API / fact | Status | Notes |
|---|---|---|
| `View.onHingeChange(isEnabled:_:)` → `(DeviceHingeContext, DeviceHingeContext)`; `context.hinge: DeviceHinge?`; `DeviceHinge.angle: Angle`; `DeviceHinge.status` ∈ `.closed / .partiallyOpen / .fullyOpen` | **Confirmed** | `hinge == nil` means no hinge (any non-Duo device). Exact `@available` version is assumed to be iOS 27.1: guard with `if #available(iOS 27.1, *)`. |
| `UIHingeInteraction(updateHandler:)`, `update.hinge` (`UIHinge`, angle in radians `CGFloat`, status includes extra `.unknown`) | **Confirmed** | `hinge` becomes nil when the interaction leaves a hierarchy that provides hinge updates. |
| Hinge angle range, update rate, precision | **Not documented** ("system policy") | Never map absolute angles to outcomes. Use relative angle from an anchor, plus a calibration step. Smooth between samples. |
| `ArrangementView { } secondary: { }`, `.arrangementViewStyle(.split)`, `.split.axes(.horizontal)`, `.overlay`, `@Environment(\.overlayArrangementZIndex)`; UIKit `UIArrangementViewController` | **Confirmed** (iOS 27.1) | Put it inside a `NavigationStack`, never inside `List` / `ScrollView`. |
| `GeometryProxy.reservedRegions(kind:options:layoutDirectionBehavior:)`, kinds `.division` (fold) and `.occlusion` (cameras), option `.includeInactive`; `UIView.reservedRegions(kind:options:)` | **Confirmed** | The fold region is active only while the device is partially folded and has zero width when flat. Reported to be empty on the first layout pass, so re-query with `onGeometryChange`. |
| `.sceneAccessory { CameraCaptureAccessory(isEnabled:) { … } .onAvailabilityChange { } }`; UIKit `UISceneAccessory.cameraCapture(sceneConfiguration:userInfo:)` + `registerSceneAccessory(_:)` | **SwiftUI confirmed**; UIKit names are from a third-party write-up (**verify**) | Available only while the app is full screen on the inner display, in the foreground, with an active capture session (an `ARSession` also qualifies). Goes away when the device closes. Whether accessory views receive touches is **UNCONFIRMED**: treat them as display-only. |
| Non-camera scene accessories for third parties (outer display UI without a camera session) | **UNCONFIRMED / not available as far as public docs show** | Don't design around it. |
| `.builtInOuterUltraWideCamera`, `.builtInInnerUltraWideCamera`, Virtual Front Camera (position `.front`), `AVCaptureDeviceDirectionCoordinator(view:deviceTypes:changeHandler:)`, `AVCaptureDeviceDescriptor`, `AVCaptureDevice.dynamicAspectRatio`, `AVCaptureDeviceRotationCoordinator`, `AVCapturePhotoOutput.isCameraSensorOrientationCompensationEnabled` | **Confirmed** (tech talk 111465) | Inner camera: 1080p up to 60 fps. Outer front: up to 4K/120. The inner camera is unavailable while closed. Ask the direction coordinator; don't infer from the hinge. |
| `AVCaptureMultiCamSession` on Duo | **Confirmed in principle** (Apple engineer: up to 3 physical cameras) | Specific combinations: **runtime only** via `AVCaptureMultiCamSession.isMultiCamSupported` and `AVCaptureDevice.DiscoverySession.supportedMultiCamDeviceSets`. |
| New windows on the outer display | **Not allowed** | Use `UIWindowSceneActivation` for new-window UI; it hides itself when unavailable. Handle scene-request errors. |
| A public "which display am I on" API | **Not found** | For layout use size/traits. For cameras use the direction coordinator. For behavior, treat `hinge.status == .closed` as "on outer display" (heuristic, **verify on device**). |
| Background hinge events / lifetime fold count | **Not found** | Count only while the app is in the foreground. |
| Simulator posture control from CLI | **No official command** (`simctl` has no posture/hinge subcommand) | Device Hub UI has Closed / Open / Rotate buttons and an Option-key hinge slider. The third-party `hinge` CLI (github.com/artemnovichkov/hinge) uses a private protocol. Use it for local experiments only, never in CI gates. |

**FoldCheck-specific limits (be honest in-app and in the report):**
- **No battery health, cycle count, serial number, IMEI, or system "lifetime folds"** are available to third-party apps. `UIDevice.batteryLevel/batteryState` gives only the current charge.
- **Fold counting** is only possible **while FoldCheck is running in the foreground** (no background hinge events: confirmed). The "fold counter" is an in-app session statistic, never a device lifetime counter.
- Hinge angle range/precision are undocumented. The hinge test checks **continuity and consistency** (monotonic sweep, no gaps/jumps, status transitions) rather than absolute accuracy.
- The report is a **user-generated inspection snapshot, not an official certification**.

## 1. PRD background

**Positioning:** A 5-minute health check for your foldable: hinge, crease, both screens, touch along the fold, cameras, speakers, and Touch ID. Get a tamper-evident PDF report for resale, insurance, or before an AppleCare claim.

**Target users:** Duo owners worried about durability; buyers and sellers of used foldables; people filing insurance/AppleCare claims who want dated evidence; refurbishers and small repair shops (later).

**Pain point + evidence:**
- Used-value questions: two batteries, crease, "Will there be statistics on # of lifetime folds?", how to judge the hinge https://www.reddit.com/r/iPhoneFold/comments/1wfkieq/ (0/19)
- Fold-counting apps are used on other foldables: "I have an app that counts the total folds" https://www.reddit.com/r/iPhoneFold/comments/1wfkrpx/comment/p9mwndi/ ; Pixel "Unfolded. It counts your folds…" https://www.reddit.com/r/PixelFold/comments/1vtfkd0/comment/p4t0mf9/ ; "I wish there was a way to see what ratio of cover to front screen ive used" https://www.reddit.com/r/GalaxyFold/comments/1wycsc9/comment/pe1qqi4/
- Durability anxiety: crease thread **1414/389** https://www.reddit.com/r/iPhoneFold/comments/1wc3vql/ ; AppleCare repair pricing 488/117 https://www.reddit.com/r/iPhoneFold/comments/1wj5kmq/ ; fingernail marks https://www.reddit.com/r/iPhoneFold/comments/1wg1536/ ; climbing chalk https://www.reddit.com/r/iPhoneFold/comments/1wisnpf/ ; kids https://www.reddit.com/r/iPhoneFold/comments/1we2may/ ; inner screen durability https://www.reddit.com/r/iPhoneFold/comments/1w32mj7/

**Selling points:** (1) guided tests made for foldables: touch along the crease, crease visibility, hinge sweep, both displays; (2) dated, tamper-evident PDF with QR verification (works offline); (3) history: compare this month vs last month; (4) honest about what can't be measured; (5) no account, nothing uploaded.

**Pricing:** Free: run every test and see results on screen. **FoldCheck Reports, one-time $2.99**: unlimited PDF reports, history and comparison, monthly check-up reminders, the in-app fold counter stats page. (Notion: $1.99 per report or $4.99/yr → simplified to one-time $2.99 per Reddit pricing feedback.)

**Success metrics:** 5,000 downloads in 90 days; ≥6% conversion; ≥4.4★; ≥30% of payers generate ≥ 2 reports (local only).

## 2. MVP scope

| ID | Test / feature | Detail | Device |
|---|---|---|---|
| T1 | **Touch grid (both displays)** | Full-screen grid (cell ~7 mm); the user swipes to fill every cell; **dense band around the crease** (cells ½ size within ±10 mm of the fold); misses highlighted; multi-touch count test (up to 10 fingers). Outer display run when closed, inner when open; the app prompts to fold/unfold between runs and auto-detects posture | Any (crease band only on Duo) |
| T2 | **Dead/stuck pixels & uniformity** | Full-screen solid colors (black, white, red, green, blue, 50% gray) with tap-to-advance; the user marks issues by tapping where they see them (stores normalized points); brightness max suggestion | Any |
| T3 | **Crease visibility** | Gray gradient and line pattern at the crease; the user rates crease visibility 1–5 at 3 viewing angles (guided); optional photo **imported** from Photos (taken with another device under angled light: guided instructions) attached to the report | Duo (inner) |
| T4 | **Hinge sweep** | "Close slowly to ~20°, then open slowly to flat" twice: records angle samples, checks monotonic progress, gaps > X°, jitter at rest, status transitions (`closed`/`partiallyOpen`/`fullyOpen`) observed; results: continuity score, observed range, max gap, sample rate estimate. Also hold tests at ~90° for 5 s (stability/drift) | Duo |
| T5 | **Cameras** | Open each available camera (rear wide/ultra-wide, outer front, inner front via `DiscoverySession`), show preview, capture a test frame, compute basic sharpness/exposure stats (no images stored unless the user opts to attach) | Any |
| T6 | **Audio** | Speakers (play left/right test tones; user confirms), microphone (record 3 s, playback, level meter), earpiece (where routable) | Any |
| T7 | **Touch ID** | `LAContext.evaluatePolicy(.deviceOwnerAuthenticationWithBiometrics)`: pass/fail only (biometry type reported) | Any with Touch ID |
| T8 | **Sensors & haptics** | Accelerometer/gyro live check (CoreMotion), proximity sensor via `UIDevice.isProximityMonitoringEnabled` (availability on Duo UNCONFIRMED: skip the check if enabling fails), Taptic Engine pattern test (user confirms) | Any |
| T9 | **Buttons** | Volume up/down detection (observing `AVAudioSession.outputVolume` changes in a test session); side button / Camera Control not detectable → user checklist | Any |
| F1 | **Inspection session & score** | Runs T1–T9 in order (skippable), each Pass / Attention / Fail / Skipped, with notes; overall summary | — |
| F2 | **PDF report** (paid) | PDFKit/`UIGraphicsPDFRenderer`: device model (`utsname.machine` → friendly name table), iOS version, storage capacity, date/time + time zone, test results with charts (hinge sweep plot, touch grid heatmap), user notes, optional attached photos, **disclaimer**, QR code | — |
| F3 | **Tamper evidence** | Per-install P-256 signing key in the Secure Enclave (`SecKeyCreateRandomKey` with `kSecAttrTokenIDSecureEnclave`); the report's canonical JSON is signed; the QR encodes `{reportID, sha256, signature, publicKey}` (compact base64, or a deep link `foldcheck://verify?...` that only opens locally). "Verify report" screen: scan a QR/import a PDF → checks the signature and hash. **It proves the PDF wasn't edited after creation by that install; it does not prove device genuineness.** Say so. | — |
| F4 | **History & compare** (paid) | Past sessions list; compare two sessions (touch misses, crease rating, hinge continuity) | — |
| F5 | **Fold counter** (paid stats; counting always on while app open) | Counts closed→open cycles and time per display **while FoldCheck is in the foreground**; displayed as "Folds observed by FoldCheck" | Duo |
| F6 | **Monthly reminder** | Local notification (`UNUserNotificationCenter`) | — |
| F7 | Paywall, Settings, Help | Honest FAQ ("Why can't you read battery health?") | — |

**Non-goals:** battery health; reading serial/IMEI; network-based "certificates"; cloud backup; buy/sell marketplace; repair-shop multi-device mode (backlog); measuring crease depth physically (impossible); claims of hinge accuracy in degrees.

**Backlog:** shop mode (batch reports, store logo); compare vs "known good" crowd baselines (needs a server → no); Apple Watch? no; export JSON; Shortcuts "Run quick check".

## 3. Fold-state behavior matrix

| State | Behavior |
|---|---|
| `closed` (outer) | Runs outer display tests (T1/T2 outer), cameras available on outer side; hinge test prompts "Open your Duo" |
| `partiallyOpen` | Hinge sweep in progress; T3 crease visibility viewing-angle steps; layout splits instructions/visuals across halves; keep controls off the crease (`reservedRegions(.division)`), except T1/T3 which intentionally draw on the crease band (no buttons there) |
| `fullyOpen` | Inner display T1/T2/T3; inner camera test |
| Transitions | Expected during T4; elsewhere: a test in progress pauses with "Display changed: continue on this screen?" and records which display each result belongs to |
| Rotation | Touch grid locks orientation during a run; reports store orientation |
| Split View | Tests require full screen → blocking explanation |
| `noHinge` | Hinge-dependent tests (T3, T4, F5, crease band in T1) are marked "Not applicable on this device"; all others run |
| iPad compat | Same as noHinge; display tests cover the compat window only → warn |

## 4. Flows and screens

Root: Home (Start inspection, Last result, History, Verify report). Inspection = stepper flow (progress bar, one test per screen). Results → Report (paywall if needed).

| Screen | States |
|---|---|
| S1 Home | first run; last result summary |
| S2 Test intro (per test) | instructions + "Start"; not applicable state |
| S3 Test run | running; paused (display changed); **permission denied** (camera/mic: test marked Skipped with reason + Settings link); **Touch ID not enrolled / locked out** (Attention with explanation); hardware unavailable |
| S4 Test result | Pass/Attention/Fail + notes field |
| S5 Summary | overall; missing tests; "Create report" |
| S6 Report preview | generating (progress); preview (PDFView); share/save; signing failed (Secure Enclave unavailable on simulator → software key fallback flagged "unsigned-dev") |
| S7 History / Compare | empty; list; compare |
| S8 Verify | scanner (camera permission) or import; valid / invalid / unknown key |
| S9 Paywall | loading; offline; pending; purchased |
| S10 Settings/Help | — |

Offline: fully offline.

## 5. UI / design brief

- **Direction:** clinical but friendly: a "vet check-up" for your phone. White/graphite surfaces, precise grid lines, one trust color (suggest deep green for Pass, amber for Attention, red for Fail, always with icons + words).
- **Layout:** the stepper header shows progress; test canvases are full-bleed (no chrome) with a small floating "Done/Skip". On the inner display, instructions go on the left half and the visual on the right where possible (except full-screen tests).
- **Components:** TestCard, ResultBadge, TouchGridCanvas, HingeSweepChart (Swift Charts), CreaseRatingControl, CameraTestTile, ToneTestControl, SignatureBadge ("Signed on this iPhone"), QRView.
- **Type:** SF Pro; SF Mono for IDs and hashes; Dynamic Type in all non-canvas screens.
- **Color & modes:** light/dark; test patterns are absolute colors (not adaptive).
- **Motion:** minimal; Reduce Motion respected.
- **Accessibility:** VoiceOver guidance for each test (some tests are visual: provide "Mark as Skipped (needs sighted help)"); touch grid supports an assistive mode (fills by tapping cells instead of swiping); large controls.
- **Localization:** en + zh-Hans (report in the user's language with an option for English for resale abroad).
- **Report design:** A4/Letter, 2–4 pages, header with logo + date + report ID, summary table, charts, disclaimer footer, QR.
- **Screenshots:** touch grid along the crease; hinge sweep chart; PDF report with QR; history compare. **Icon:** a stethoscope tracing a fold line.

## 6. Technical architecture

**Stack:** Swift 6, SwiftUI, Swift Charts, AVFoundation (camera/audio), CoreMotion, LocalAuthentication, PDFKit + `UIGraphicsPDFRenderer`, CryptoKit + Security (Secure Enclave P-256), CoreImage (`CIQRCodeGenerator`), VisionKit `DataScannerViewController` for QR scanning (or AVFoundation metadata output), UserNotifications, SwiftData, StoreKit 2, FoldKit + `HingeInput` (shared with HingeLab/FoldPlay).

All fold logic goes through one small local Swift package, **`FoldKit`**. It's the same package in every iOS project in this portfolio: copy it in as `Packages/FoldKit`. Nothing else in the app may call `onHingeChange` / `UIHingeInteraction` directly.

```swift
// Packages/FoldKit/Sources/FoldKit/FoldState.swift
import SwiftUI
import Observation

public enum FoldPosture: String, Codable, Sendable, CaseIterable {
    case noHinge        // non-Duo iPhone, iPad, Mac ("Designed for iPad"), or hinge context unavailable
    case closed         // folded; app is (assumed) on the outer display
    case partiallyOpen  // flexed / half-folded (laptop, book, tent… system does not tell which)
    case fullyOpen      // flat; app on inner display
    case unknown        // UIKit `.unknown`, or transient states
}

public struct FoldState: Equatable, Sendable {
    public var posture: FoldPosture
    /// Degrees exactly as reported by the system. `nil` when there is no hinge.
    /// The range is NOT documented. Never compare to absolute thresholds without calibration.
    public var angleDegrees: Double?
    public var timestamp: Date
    public init(posture: FoldPosture, angleDegrees: Double?, timestamp: Date = .now) {
        self.posture = posture; self.angleDegrees = angleDegrees; self.timestamp = timestamp
    }
    public static let noHinge = FoldState(posture: .noHinge, angleDegrees: nil, timestamp: .distantPast)
    public var hasHinge: Bool { posture != .noHinge }
}

@MainActor
public protocol FoldStateProvider: AnyObject, Observable {
    var state: FoldState { get }
    /// Yields the current value immediately, then every change.
    func states() -> AsyncStream<FoldState>
}

/// Production provider. Fed by `HingeBridge`, attached once at the root of every scene.
@MainActor @Observable
public final class SystemFoldStateProvider: FoldStateProvider { /* stores state, fans out to continuations */ }

/// Test / preview / UI-test provider. Driven by code or by launch arguments (see §8).
@MainActor @Observable
public final class MockFoldStateProvider: FoldStateProvider {
    public func set(_ posture: FoldPosture, angle: Double? = nil)
    public func play(_ script: [FoldScriptStep]) async   // e.g. sweep 180→0 over 2 s at 30 Hz
}

public struct HingeBridge: ViewModifier {
    let provider: SystemFoldStateProvider
    public func body(content: Content) -> some View {
        if #available(iOS 27.1, *) {                     // availability version assumed. Verify in Xcode 27.1
            content.onHingeChange { _, ctx in provider.ingest(ctx.hinge) }   // maps DeviceHinge → FoldState
        } else {
            content.onAppear { provider.ingestNoHinge() }
        }
    }
}

/// Converts noisy absolute angles into a stable 0…1 control value.
public struct RelativeAngleTracker: Sendable {
    public var anchorDegrees: Double?             // set when the interaction starts
    public var observedMin: Double, observedMax: Double   // learned during calibration
    public var smoothing: Double = 0.25           // EMA factor; animate between samples
    public mutating func begin(at degrees: Double)
    public mutating func update(_ degrees: Double) -> Double     // returns normalized progress 0…1
    public mutating func delta(_ degrees: Double) -> Double       // signed degrees since anchor
    public mutating func reset()
}
```

Rules:
- `DeviceHinge.status` mapping: `.closed → .closed`, `.partiallyOpen → .partiallyOpen`, `.fullyOpen → .fullyOpen`, `@unknown default → .unknown`. A `nil` hinge maps to `.noHinge`.
- Inject the provider through the SwiftUI environment: `@Environment(\.foldState)`. Feature code depends on the `FoldStateProvider` protocol, never on the concrete class.
- Launch argument `-FoldMock <value>` swaps in `MockFoldStateProvider`. Values: `nohinge`, `closed`, `open`, `half:<deg>`, `sweep:<from>-<to>:<seconds>`, `script:<bundled-json-name>`. It is only honored in DEBUG builds or when `-UITestMode 1` is present.
- Every hinge-driven interaction must also have a non-hinge control (slider, buttons, drag, or tilt) with identical results. This covers non-Duo devices, VoiceOver users, and App Review on devices without a hinge.

**Modules:** `FoldKit`, `HingeInput` (shared), `TestsKit` (each test as a model + view; protocol below), `HingeAnalysis` (sweep analysis: monotonic segments, gaps, jitter, sample-rate estimation: pure functions), `ReportKit` (canonical JSON, PDF rendering, signing, QR, verify), `Library` (SwiftData sessions), `Store`, `App`.

**Key types:**
```swift
enum TestID: String, Codable, CaseIterable { case touchGridOuter, touchGridInner, pixels, crease, hingeSweep, cameras, audio, touchID, sensors, buttons }
enum TestOutcome: String, Codable { case pass, attention, fail, skipped, notApplicable }
struct TestResult: Codable, Identifiable { var id: TestID; var outcome: TestOutcome; var metrics: [String: Double]; var notes: String; var display: DisplayKind? /* outer, inner */; var attachments: [String]; var finishedAt: Date }
@Model final class InspectionSession { @Attribute(.unique) var id: UUID; var startedAt: Date; var deviceModel: String; var osVersion: String; var resultsData: Data /* [TestResult] JSON */; var reportFile: String?; var signatureB64: String? }
struct HingeSample: Equatable { var degrees: Double; var status: FoldPosture; var t: TimeInterval }
struct HingeSweepReport: Codable { var observedMin: Double; var observedMax: Double; var maxGapDegrees: Double; var restJitterDegrees: Double; var estimatedHz: Double; var monotonicFraction: Double; var statusSequence: [FoldPosture] }
protocol InspectionTest { static var id: TestID { get }; static func isApplicable(_ ctx: DeviceContext) -> Bool; func makeView(complete: @escaping (TestResult) -> Void) -> AnyView }
struct ReportEnvelope: Codable { var reportID: UUID; var sha256: String; var signature: String; var publicKey: String; var version: Int }
```

**Persistence:** SwiftData sessions; PDFs and attachments in Application Support/Reports; signing key in Secure Enclave (Keychain reference, this-device-only); settings in UserDefaults.

**Permissions:**
- `NSCameraUsageDescription`: "FoldCheck tests your cameras and scans report QR codes. Test images aren't saved unless you attach them to a report." / "FoldCheck 用于测试摄像头并扫描报告二维码。除非你把测试图片附加到报告中，否则不会保存。"
- `NSMicrophoneUsageDescription`: "Test your microphone with a short recording that stays on your iPhone." / "通过一段保留在本机的简短录音测试麦克风。"
- `NSFaceIDUsageDescription` is only required for Face ID. The Duo has Touch ID, so omit it unless Xcode or App Review flags it; LocalAuthentication works for Touch ID without it.
- Notifications: runtime permission for monthly reminders (no Info.plist key).

Privacy stance: **no tracking, no data collection off-device.** App Store privacy label: **Data Not Collected.** No third-party SDKs. No `NSUserTrackingUsageDescription`, no ATT prompt.

Base `PrivacyInfo.xcprivacy` (add a required-reason entry only for APIs the app actually touches. The reason codes below are Apple's published codes; re-check against the current list when submitting):

```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
  <key>NSPrivacyTracking</key><false/>
  <key>NSPrivacyTrackingDomains</key><array/>
  <key>NSPrivacyCollectedDataTypes</key><array/>
  <key>NSPrivacyAccessedAPITypes</key><array>
    <dict>
      <key>NSPrivacyAccessedAPIType</key><string>NSPrivacyAccessedAPICategoryUserDefaults</string>
      <key>NSPrivacyAccessedAPITypeReasons</key><array><string>CA92.1</string></array>
    </dict>
    <!-- add FileTimestamp (C617.1) if you read file modification dates in the app container -->
    <!-- add DiskSpace (E174.1) if you check free space before writing large files -->
  </array>
</dict></plist>
```
Widget / app extensions get their own copy of the manifest.
FoldCheck entries: UserDefaults CA92.1, FileTimestamp C617.1, DiskSpace E174.1 (storage capacity shown in report: `volumeTotalCapacity`), SystemBootTime 35F9.1 if `systemUptime` is used for sample timing (use `CACurrentMediaTime`/`ProcessInfo.systemUptime` → include).

**StoreKit:** `com.jackyu.foldcheck.reports` non-consumable $2.99.
StoreKit 2 implementation (shared pattern, `Store` module):
- `@MainActor @Observable final class Store`: loads products with `Product.products(for:)`, starts a `Transaction.updates` listener at launch, and recomputes entitlements from `Transaction.currentEntitlements`. Every `VerificationResult` is checked; `.unverified` grants nothing.
- Purchase: `product.purchase()`. Handle `.success(.verified)` (then `transaction.finish()`), `.pending` (Ask to Buy / SCA: show a "Waiting for approval" state), and `.userCancelled` (silently return).
- Restore: a "Restore Purchases" button calls `AppStore.sync()`. Also show it in Settings.
- Refunds / revocation: a transaction with `revocationDate != nil` removes the entitlement immediately (next launch at the latest).
- Family Sharing: enable it in App Store Connect for the non-consumable unlock(s). The code doesn't change.
- Offline: cache the last computed entitlement set in `UserDefaults` only to avoid a paywall flash, and always re-verify when `currentEntitlements` arrives.
- The paywall uses SwiftUI `ProductView` / `StoreView` where it fits (it localizes prices automatically). Never hardcode prices in UI strings.
- Local testing: a `Configuration.storekit` file in the repo, selected in the Run scheme. Unit tests use `StoreKitTest.SKTestSession` (purchase, Ask-to-Buy, refund, expire, failure).

**Project tree:**
```
foldcheck-ios/
├─ FoldCheck.xcodeproj
├─ App/ (Home/, Inspection/, Tests/{TouchGrid, Pixels, Crease, HingeSweep, Cameras, Audio, TouchID, Sensors, Buttons}, Summary/, Report/, History/, Verify/, Paywall/, Settings/)
│  ├─ Resources/ Localizable.xcstrings, Assets.xcassets, DeviceNames.json, DisplaySpec.json (crease band location)
│  ├─ Info.plist, PrivacyInfo.xcprivacy
├─ Packages/ FoldKit/ HingeInput/ TestsKit/ HingeAnalysis/ ReportKit/ Library/ Store/
├─ Tests/ UITests/
└─ Configuration.storekit
```

## 7. Edge cases

- Hinge readings never arrive on a Duo (context not provided) → T4 marked "Unavailable" with a retry; never Fail because of an API gap.
- User sweeps too fast → "Too fast, go slower" with a speed meter; analysis requires ≥ N samples per 10°.
- Hinge range observed smaller than expected (e.g., 30°–170°) → not a failure (undocumented range); report the observed values.
- Touch grid: protector/case edge prevents edge cells → allow marking cells "blocked by case"; accessibility tapping mode.
- Display test on a display with True Tone/Night Shift → advise turning them off for color tests (can't detect Night Shift; ask).
- Brightness can't be set to max programmatically in a nice way → `UIScreen.main.brightness` can be set temporarily (restore after) on the active display. Check per-display behavior on Duo.
- Camera unavailable (closed → inner camera) → mark per-camera N/A.
- Mic test in a noisy room → level meter only; user confirms playback.
- Touch ID: not enrolled → Attention ("Set up Touch ID to test"); lockout → instruct passcode.
- Secure Enclave unavailable (simulator) → software key, report marked "Development build: unsigned".
- PDF generation memory with many photos → downscale attachments to 1600 px.
- Clock tampering (user sets the date back) → the report records the date as given; disclaimer.
- Verify a report from another install → valid signature with an unknown key; show "Signed by another device (key fingerprint …)".
- Restoring the app on a new phone → new signing key; old reports still verify (public key embedded).
- Refund → reports already generated stay; new ones locked.

## 8. Testing plan

How to simulate fold states and hinge angles:
1. **Unit tests (fast, CI):** inject `MockFoldStateProvider`. Drive `set(.closed)`, `set(.partiallyOpen, angle: 95)`, `set(.fullyOpen)`, `set(.noHinge)` and scripted sweeps, and assert on view-model state. No simulator posture needed.
2. **UI tests (XCUITest, CI):** launch with `-UITestMode 1 -FoldMock <value>`. A hidden DEBUG-only "Fold debug" overlay (toggled with `-FoldDebugOverlay 1`) exposes buttons with accessibility identifiers `fold.closed`, `fold.half`, `fold.open`, `fold.nohinge`, `fold.sweep`, so a UI test can change the mocked posture mid-flow. Mocking changes hinge signals only. It does **not** resize the window.
3. **Real layout changes (manual or semi-automated):** run on the **iPhone Duo simulator** (Xcode 27.1, Device Hub). Use the Closed / Open / Rotate buttons, and hold Option for the hinge-angle slider. This is the only official way to test true outer↔inner resizing, reserved regions, and split view. `simctl` has no posture command.
4. **Optional local helper:** the third-party `hinge` CLI (`hinge 120`, `hinge sweep 180 0 2`) sets the simulator hinge through a private, undocumented protocol. Use it for local exploration only, and never make a CI gate depend on it.
5. **Non-Duo fallback:** run the same UI tests on an iPhone 17/18 simulator with `-FoldMock nohinge`, and without any mock, to verify `hinge == nil` handling.

**Unit:** HingeAnalysis with synthetic sweeps (clean, gappy, jittery, reversed, partial range) → expected metrics; status sequence detection; touch grid coverage math (cell mapping incl. crease band from `DisplaySpec`); report canonical JSON stability (golden); sign/verify round-trip with a software key; tamper detection (flip one byte → invalid); QR payload size within version-10 QR capacity; device-name mapping; outcome aggregation; Store gating.

**UI tests:** `-UITestMode 1 -FoldMock sweep:10-180:6` → hinge test shows Pass with continuity metrics; `-FoldMock script:<gappy.json>` → Attention; `-FoldMock nohinge` → hinge tests "Not applicable"; full inspection with tests auto-completed via a DEBUG hook `-AutoCompleteTests pass` → summary → report generation (paid via StoreKit test config) → PDF exists; verify flow imports that PDF → valid.

**Real device needed:** real hinge data (range, rate, jitter) for thresholds; touch along the crease; camera list; brightness behavior per display; Secure Enclave signing.

**Acceptance criteria:**
- AC1: The full inspection (all applicable tests) can be completed in ≤ 6 minutes on a Duo by a first-time user (hallway test).
- AC2: Synthetic hinge fixtures produce correct outcomes: clean → Pass; a 25° gap → Attention; non-monotonic jumps → Attention; no data → Unavailable (never Fail).
- AC3: The touch grid detects 100% of cells including the crease band in a scripted UI test (synthetic touches).
- AC4: A generated PDF contains device model, OS, date/time zone, all results, the disclaimer, and a QR. `ReportKit.verify` returns valid for it and invalid after any byte change in the embedded JSON.
- AC5: On a non-Duo iPhone, hinge-specific tests are N/A and every other test runs.
- AC6: Camera/mic denial → the respective test is Skipped with a reason; the inspection continues.
- AC7: The fold counter increments only for closed→open transitions observed while the app is in the foreground (mock-driven test), and the UI labels it accordingly.
- AC8: Free users can run all tests; report/history/compare require the purchase (StoreKit test).
- AC9: No network calls (proxy check).
- AC10: en + zh-Hans complete; report renders in both.

## 9. App Store review risks

| Risk | Mitigation |
|---|---|
| **2.3.1 accuracy / misleading claims** ("certified", "battery health") | Never claim certification or battery health; disclaimers in-app and in PDFs. |
| 4.2 minimum functionality | Nine guided tests + reports + verification. |
| 5.1.1 privacy (camera/mic) | Purpose strings; nothing stored by default; Data Not Collected. |
| Apple trademark ("AppleCare") in metadata | Use "warranty or insurance claims" in metadata; avoid "AppleCare" in the name/subtitle/keywords. |
| Diagnostic apps reviewed for "fake" tests | Tests measure real things; describe their limits. |

## 10. Milestones

| # | Milestone | Tasks | Est. |
|---|---|---|---|
| M0 | Spike | Hinge sampling in the simulator (Option-slider) and later on device; brightness per display; camera list; Secure Enclave on device | 0.5 d |
| M1 | Skeleton | FoldKit + HingeInput (shared), TestsKit protocol, stepper flow, SwiftData, String Catalog, privacy manifest, CI | 1.5 d |
| M2 | Display & touch tests | T1 (both displays + crease band), T2, T3 (AC3) | 2.5 d |
| M3 | Hinge test + fold counter | T4 + HingeAnalysis + F5 (AC2, AC7) | 2 d |
| M4 | Hardware tests | T5–T9 | 2 d |
| M5 | Reports | PDF, signing, QR, verify (AC4) | 2.5 d |
| M6 | History, reminders, Store | F4, F6, paywall (AC8) | 1.5 d |
| M7 | Polish | a11y modes, zh-Hans, screenshots, Review Notes (AC10) | 1 d |
| | **Total** | | **≈13.5 dev-days** |

## 11. Open questions & assumptions

1. Real hinge sample characteristics (rate, quantization, observed range) for setting Attention thresholds.
2. Does `UIScreen.brightness` (or the scene's screen) control each Duo display independently?
3. Proximity sensor exposure on Duo (assumed not testable; T8 drops it if unavailable).
4. Volume-button detection via `outputVolume` KVO still works in iOS 27 (assumed yes).
5. Will buyers trust a self-signed report? Market test; it's honest by design.
6. Merge with HingeLab later as a "Hinge Suite"? Keep separate for now (different buyers: resale vs music).


---
*Spec version 1.0 · 2026-10-13 · Prepared for Jack Yu. API facts were checked against Apple developer sources on that date (see the API status table). Items marked UNCONFIRMED or "verify" must be validated in M0 or on a real device.*
