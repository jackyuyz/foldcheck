import SwiftUI
import UIKit
import FoldKit
import FoldL10n
import TestsKit
import ReportKit

// MARK: - Registry

/// Which tests this build has real screens for. Everything else is recorded as Skipped
/// ("not available in this version yet") instead of pretending to run.
enum InspectionTestRegistry {
    static let implemented: Set<TestID> = Set(TestID.allCases)
}

// MARK: - Device info

/// Device model and OS for the session header, read from the device (not hardcoded).
enum DeviceInfo {
    /// `utsname.machine`, or the simulated model on the simulator (where `machine` is just "arm64").
    static var modelIdentifier: String {
        if let simulated = ProcessInfo.processInfo.environment["SIMULATOR_MODEL_IDENTIFIER"], !simulated.isEmpty {
            return simulated
        }
        var systemInfo = utsname()
        uname(&systemInfo)
        return withUnsafeBytes(of: &systemInfo.machine) { buffer in
            String(decoding: buffer.prefix { $0 != 0 }, as: UTF8.self)
        }
    }

    static var isSimulator: Bool {
        #if targetEnvironment(simulator)
        return true
        #else
        return false
        #endif
    }

    /// Friendly model name, e.g. "iPhone 17 Pro (Simulator)".
    static var displayName: String {
        let name = DeviceNames.friendlyName(for: modelIdentifier)
        return isSimulator ? "\(name) (Simulator)" : name
    }

    @MainActor
    static var osVersion: String {
        "\(UIDevice.current.systemName) \(UIDevice.current.systemVersion)"
    }

    /// Context for deciding which tests apply, from the current (possibly mocked) fold state.
    @MainActor
    static func context(foldState: FoldState) -> DeviceContext {
        DeviceContext(
            foldState: foldState,
            modelIdentifier: modelIdentifier,
            osVersion: osVersion,
            biometricType: biometricType
        )
    }
}

// MARK: - Fold state observation

extension View {
    /// Keeps `binding` in sync with the injected fold state provider (mock or system).
    func observeFoldState(_ binding: Binding<FoldState>) -> some View {
        modifier(FoldStateObserver(state: binding))
    }
}

private struct FoldStateObserver: ViewModifier {
    @Environment(\.foldStateProvider) private var provider
    @Binding var state: FoldState

    func body(content: Content) -> some View {
        content.task {
            state = provider.state
            for await next in provider.states() {
                state = next
            }
        }
    }
}

/// Pauses a running test when the app moves between the outer and inner display
/// ("Display changed: continue on this screen?"), and reports the new display on continue.
struct DisplayChangePause: ViewModifier {
    let foldState: FoldState
    let onContinue: (DisplayKind?) -> Void
    @Environment(\.appLanguage) private var language
    @State private var baseline: DisplayKind?
    @State private var hasBaseline = false
    @State private var pendingDisplay: DisplayKind?
    @State private var isPaused = false

    func body(content: Content) -> some View {
        content
            .onAppear {
                guard !hasBaseline else { return }
                baseline = DisplayKind(posture: foldState.posture)
                hasBaseline = true
            }
            .onChange(of: foldState.posture) { _, posture in
                let display = DisplayKind(posture: posture)
                // `unknown` is transient; only a real outer↔inner switch pauses.
                guard let display, display != baseline else { return }
                pendingDisplay = display
                isPaused = true
            }
            .overlay {
                if isPaused {
                    ZStack {
                        Color.black.opacity(0.75).ignoresSafeArea()
                        VStack(spacing: 16) {
                            Image(systemName: "rectangle.portrait.on.rectangle.portrait.angled")
                                .font(.largeTitle)
                            Text(L10nKey.testDisplayChangedTitle.text(in: language))
                                .font(.title3.bold())
                            Text(L10nKey.testDisplayChangedMessage.text(in: language))
                                .multilineTextAlignment(.center)
                            Button(L10nKey.testDisplayChangedContinue.text(in: language)) {
                                baseline = pendingDisplay
                                isPaused = false
                                onContinue(pendingDisplay)
                            }
                            .buttonStyle(.borderedProminent)
                .tint(InspectionStyle.buttonFill)
                            .accessibilityIdentifier("test.displayChanged.continue")
                        }
                        .foregroundStyle(.white)
                        .padding(24)
                        .frame(maxWidth: 360)
                    }
                }
            }
    }
}

// MARK: - Supported orientations

/// Touch tests follow rotation; their coverage is reset when canvas geometry changes.
final class AppDelegate: NSObject, UIApplicationDelegate {
    func application(
        _ application: UIApplication,
        supportedInterfaceOrientationsFor window: UIWindow?
    ) -> UIInterfaceOrientationMask {
        .allButUpsideDown
    }
}

// MARK: - Brightness

/// Raises the active display to full brightness for the pixel test and restores it afterwards.
@MainActor
final class BrightnessBoost {
    private var saved: (screen: UIScreen, brightness: CGFloat)?

    func begin() {
        guard saved == nil,
              let screen = UIApplication.shared.connectedScenes
                .compactMap({ ($0 as? UIWindowScene)?.screen })
                .first else { return }
        saved = (screen, screen.brightness)
        screen.brightness = 1
    }

    func end() {
        guard let saved else { return }
        saved.screen.brightness = saved.brightness
        self.saved = nil
    }
}

// MARK: - Floating controls

/// Small floating control bar for full-bleed test canvases. It can jump between the top and
/// bottom edge so it never permanently hides part of the canvas.
struct FloatingTestBar<Content: View>: View {
    var dark: Bool = true
    let onCancel: () -> Void
    @ViewBuilder let content: () -> Content
    @State private var atTop = false
    @Environment(\.appLanguage) private var language

    var body: some View {
        VStack {
            if !atTop { Spacer(minLength: 0) }
            HStack(spacing: 12) {
                Button(action: onCancel) {
                    Image(systemName: "xmark")
                        .frame(width: 44, height: 44)
                }
                .accessibilityLabel(Text(L10nKey.inspectionCancel.text(in: language)))
                .accessibilityIdentifier("test.cancel")

                content()

                Button {
                    atTop.toggle()
                } label: {
                    Image(systemName: atTop ? "arrow.down.to.line" : "arrow.up.to.line")
                        .frame(width: 44, height: 44)
                }
                .accessibilityLabel(L10nKey.testMoveBar.text(in: language))
                .accessibilityIdentifier("test.moveBar")
            }
            .font(.subheadline.weight(.semibold))
            .foregroundStyle(dark ? Color.white : Color.black)
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(
                (dark ? Color.black : Color.white).opacity(0.6),
                in: Capsule()
            )
            .padding(.horizontal, 12)
            .padding(.vertical, 28)
            if atTop { Spacer(minLength: 0) }
        }
    }
}

// MARK: - Metric formatting

/// Human-readable metric lines for the result review screen and the summary.
enum ResultMetricsFormatter {
    struct Line: Hashable {
        let label: String
        let value: String
    }

    static func lines(for result: TestResult, language: AppLanguage) -> [Line] {
        let m = result.metrics
        var lines: [Line] = []
        switch result.id {
        case .touchGridOuter, .touchGridInner:
            if let percent = m[TestMetricKey.coveragePercent],
               let covered = m[TestMetricKey.cellsCovered],
               let total = m[TestMetricKey.totalCells] {
                lines.append(Line(
                    label: L10nKey.metricCoverage.text(in: language),
                    value: "\(format(percent))% (\(Int(covered))/\(Int(total)))"
                ))
            }
            if let band = m[TestMetricKey.creaseBandCoverage], let cells = m[TestMetricKey.creaseBandCells] {
                let missed = Int(m[TestMetricKey.creaseBandMissed] ?? 0)
                lines.append(Line(
                    label: L10nKey.metricCreaseBand.text(in: language),
                    value: "\(format(band))% (\(Int(cells) - missed)/\(Int(cells)))"
                ))
            }
            if let touches = m[TestMetricKey.maxTouches], touches > 0 {
                lines.append(Line(label: L10nKey.metricMaxTouches.text(in: language), value: "\(Int(touches))"))
            }
        case .pixels:
            if let issues = m[TestMetricKey.issuesMarked] {
                lines.append(Line(label: L10nKey.metricIssuesMarked.text(in: language), value: "\(Int(issues))"))
            }
        case .hingeSweep:
            if let continuity = m[TestMetricKey.monotonicFraction] {
                lines.append(Line(label: L10nKey.metricContinuity.text(in: language), value: "\(format((continuity * 1000).rounded() / 10))%"))
            }
            if let gap = m[TestMetricKey.maxGapDegrees] {
                lines.append(Line(label: L10nKey.metricMaxGap.text(in: language), value: "\(format((gap * 10).rounded() / 10))°"))
            }
            if let low = m[TestMetricKey.observedMinAngle], let high = m[TestMetricKey.observedMaxAngle] {
                lines.append(Line(label: L10nKey.metricObservedRange.text(in: language), value: "\(Int(low.rounded()))°–\(Int(high.rounded()))°"))
            }
            if let hz = m[TestMetricKey.sampleRate] {
                lines.append(Line(label: L10nKey.metricSampleRate.text(in: language), value: "\(Int(hz.rounded())) Hz"))
            }
            if let jitter = m[TestMetricKey.restJitter] {
                lines.append(Line(label: L10nKey.metricRestJitter.text(in: language), value: "\(format((jitter * 10).rounded() / 10))°"))
            }
            if let drift = m[TestMetricKey.holdDrift] {
                lines.append(Line(label: L10nKey.metricHoldDrift.text(in: language), value: "\(format((drift * 10).rounded() / 10))°"))
            }
            if let count = m[TestMetricKey.hingeSamples] {
                lines.append(Line(label: L10nKey.metricReadings.text(in: language), value: "\(Int(count))"))
            }
        case .crease:
            if let average = m[TestMetricKey.creaseRating] {
                var value = "\(format(average)) / 5"
                if let worst = m[TestMetricKey.creaseRatingMax] {
                    value += " (max \(Int(worst)))"
                }
                lines.append(Line(label: L10nKey.metricCreaseRating.text(in: language), value: value))
            }
            if m[TestMetricKey.photoAttached] == 1 {
                lines.append(Line(label: L10nKey.metricPhoto.text(in: language), value: "✓"))
            }
        case .cameras:
            if let available = m[TestMetricKey.camerasAvailable], available > 0 {
                let working = (0..<Int(available)).filter { m[TestMetricKey.cameraOK($0)] == 1 }.count
                let tested = Int(m[TestMetricKey.camerasTested] ?? 0)
                lines.append(Line(label: L10nKey.metricCamerasWorking.text(in: language), value: "\(working) / \(tested)"))
            }
        case .audio:
            let speakers = [TestMetricKey.speakerLeftConfirmed, TestMetricKey.speakerRightConfirmed].compactMap { m[$0] }
            if !speakers.isEmpty {
                lines.append(Line(
                    label: L10nKey.metricSpeakersHeard.text(in: language),
                    value: "\(speakers.filter { $0 == 1 }.count) / \(speakers.count)"
                ))
            }
            if let peak = m[TestMetricKey.micPeakLevel] {
                lines.append(Line(label: L10nKey.metricMicPeak.text(in: language), value: "\(Int(peak.rounded())) dB"))
            }
            if let heard = m[TestMetricKey.micPlaybackConfirmed] {
                lines.append(Line(label: L10nKey.metricPlaybackHeard.text(in: language), value: heard == 1 ? "✓" : "✗"))
            }
        case .sensors:
            for part in SensorPart.allCases {
                guard let ok = m[TestMetricKey.sensorOK(part)] else { continue }
                lines.append(Line(label: part.localizedName(in: language), value: ok == 1 ? "✓" : "✗"))
            }
        case .buttons:
            if let up = m[TestMetricKey.volumeUpDetected] {
                lines.append(Line(label: L10nKey.buttonsVolumeUp.text(in: language), value: up == 1 ? "✓" : "✗"))
            }
            if let down = m[TestMetricKey.volumeDownDetected] {
                lines.append(Line(label: L10nKey.buttonsVolumeDown.text(in: language), value: down == 1 ? "✓" : "✗"))
            }
            for button in PhysicalButton.allCases {
                guard let works = m[TestMetricKey.buttonWorks(button)] else { continue }
                lines.append(Line(label: button.localizedName(in: language), value: works == 1 ? "✓" : "✗"))
            }
        case .touchID:
            break
        }
        return lines
    }

    static func summary(for result: TestResult, language: AppLanguage) -> String? {
        let lines = lines(for: result, language: language)
        guard !lines.isEmpty else { return nil }
        return lines.map { "\($0.label) \($0.value)" }.joined(separator: " · ")
    }

    private static func format(_ value: Double) -> String {
        value.rounded() == value ? String(Int(value)) : String(format: "%.1f", value)
    }
}
