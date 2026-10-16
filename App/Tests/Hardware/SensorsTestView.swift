import SwiftUI
import UIKit
import CoreMotion
import CoreHaptics
import FoldKit
import FoldL10n
import TestsKit

/// T8: three steps. Tilt and turn the phone while the accelerometer and gyroscope are read;
/// cover the proximity sensor; feel three haptic taps. Parts the device or the simulator
/// doesn't offer are recorded as unavailable, never as faulty.
struct SensorsTestView: View {
    let initialFoldState: FoldState
    let onFinish: (TestResult) -> Void
    let onCancel: () -> Void

    @Environment(\.appLanguage) private var language
    @State private var session = SensorsTestSession()
    @State private var motion = MotionRecorder()
    @State private var phase: Phase = .motion(measuring: false)

    private enum Phase: Equatable {
        case motion(measuring: Bool)
        case proximity
        case haptics(played: Bool)
    }

    private static let totalSteps = 3

    var body: some View {
        switch phase {
        case .motion(let measuring):
            TestStepScreen(
                step: (1, Self.totalSteps),
                systemImage: "gyroscope",
                title: L10nKey.sensorsMotionTitle.text(in: language),
                message: L10nKey.sensorsMotionInstruction.text(in: language),
                onCancel: cancel
            ) {
                if measuring {
                    ProgressView(value: motion.progress)
                        .padding(.horizontal)
                }
            } actions: {
                StepButton(title: measuring ? L10nKey.sensorsMeasuring.text(in: language) : L10nKey.sensorsStart.text(in: language)) {
                    Task { await measureMotion() }
                }
                .disabled(measuring)
                .accessibilityIdentifier("sensors.motionStart")
            }
        case .proximity:
            TestStepScreen(
                step: (2, Self.totalSteps),
                systemImage: "hand.raised.fill",
                title: L10nKey.sensorsProximityTitle.text(in: language),
                message: L10nKey.sensorsProximityInstruction.text(in: language),
                onCancel: cancel
            ) {
                ProgressView()
            } actions: {
                StepButton(title: L10nKey.inspectionSkip.text(in: language), prominent: false) {
                    endProximity(.notConfirmed)
                }
                .accessibilityIdentifier("sensors.proximitySkip")
            }
            .onAppear(perform: startProximity)
            .onReceive(NotificationCenter.default.publisher(for: UIDevice.proximityStateDidChangeNotification)) { _ in
                if UIDevice.current.proximityState { endProximity(.ok) }
            }
        case .haptics(let played):
            TestStepScreen(
                step: (3, Self.totalSteps),
                systemImage: "iphone.radiowaves.left.and.right",
                title: L10nKey.sensorsHapticsTitle.text(in: language),
                message: played ? L10nKey.sensorsHapticsQuestion.text(in: language) : L10nKey.sensorsHapticsInstruction.text(in: language),
                onCancel: cancel
            ) {
                EmptyView()
            } actions: {
                StepButton(title: L10nKey.sensorsPlay.text(in: language), prominent: !played) {
                    Task { await playHaptics() }
                }
                .accessibilityIdentifier("sensors.hapticsPlay")
                if played {
                    YesNoButtons(identifier: "sensors.felt") { felt in
                        session.record(felt ? .ok : .notConfirmed, for: .haptics)
                        finish()
                    }
                }
            }
        }
    }

    private func measureMotion() async {
        phase = .motion(measuring: true)
        let readings = await motion.record(seconds: 4)
        session.record(
            readings.accelerometerAvailable ? SensorsTestSession.accelerometerResult(samples: readings.acceleration) : .unavailable,
            for: .accelerometer
        )
        session.record(
            readings.gyroscopeAvailable ? SensorsTestSession.gyroscopeResult(samples: readings.rotation) : .unavailable,
            for: .gyroscope
        )
        phase = .proximity
    }

    private func startProximity() {
        let device = UIDevice.current
        device.isProximityMonitoringEnabled = true
        // Enabling silently fails on devices without a proximity sensor (and in the simulator).
        if !device.isProximityMonitoringEnabled {
            endProximity(.unavailable)
        }
    }

    private func endProximity(_ result: SensorPartResult) {
        UIDevice.current.isProximityMonitoringEnabled = false
        guard phase == .proximity else { return }
        session.record(result, for: .proximity)
        if CHHapticEngine.capabilitiesForHardware().supportsHaptics {
            phase = .haptics(played: false)
        } else {
            session.record(.unavailable, for: .haptics)
            finish()
        }
    }

    private func playHaptics() async {
        let generator = UIImpactFeedbackGenerator(style: .heavy)
        generator.prepare()
        for _ in 0..<3 {
            generator.impactOccurred()
            try? await Task.sleep(for: .milliseconds(350))
        }
        phase = .haptics(played: true)
    }

    private func finish() {
        endProximityMonitoring()
        // Every part that wasn't OK, so an Unavailable or Attention result explains itself.
        let problems = SensorPart.allCases.compactMap { part -> String? in
            guard let result = session.parts[part], result != .ok else { return nil }
            return "\(part.localizedName(in: language)): \(result.localizedName(in: language))"
        }
        onFinish(session.result(notes: problems.joined(separator: "\n")))
    }

    private func endProximityMonitoring() {
        UIDevice.current.isProximityMonitoringEnabled = false
    }

    private func cancel() {
        motion.stop()
        endProximityMonitoring()
        onCancel()
    }
}

extension SensorPart {
    func localizedName(in language: AppLanguage) -> String {
        switch self {
        case .accelerometer: return L10nKey.sensorsAccelerometer.text(in: language)
        case .gyroscope: return L10nKey.sensorsGyroscope.text(in: language)
        case .proximity: return L10nKey.sensorsProximityTitle.text(in: language)
        case .haptics: return L10nKey.sensorsHapticsTitle.text(in: language)
        }
    }
}

extension SensorPartResult {
    func localizedName(in language: AppLanguage) -> String {
        switch self {
        case .ok: return L10nKey.sensorsStatusOK.text(in: language)
        case .notConfirmed: return L10nKey.sensorsStatusNotConfirmed.text(in: language)
        case .faulty: return L10nKey.sensorsStatusFaulty.text(in: language)
        case .unavailable: return L10nKey.sensorsStatusUnavailable.text(in: language)
        }
    }
}

// MARK: - Motion

/// Reads the accelerometer and gyroscope for a few seconds, on the main queue.
@MainActor
@Observable
final class MotionRecorder {
    struct Readings {
        var accelerometerAvailable = false
        var gyroscopeAvailable = false
        var acceleration: [Vector3] = []
        var rotation: [Vector3] = []
    }

    private(set) var progress = 0.0
    private let manager = CMMotionManager()

    func record(seconds: Double) async -> Readings {
        var readings = Readings(
            accelerometerAvailable: manager.isAccelerometerAvailable,
            gyroscopeAvailable: manager.isGyroAvailable
        )
        manager.accelerometerUpdateInterval = 1 / 50
        manager.gyroUpdateInterval = 1 / 50
        if readings.accelerometerAvailable { manager.startAccelerometerUpdates() }
        if readings.gyroscopeAvailable { manager.startGyroUpdates() }

        let start = Date.now
        while Date.now.timeIntervalSince(start) < seconds {
            try? await Task.sleep(for: .milliseconds(20))
            if let a = manager.accelerometerData?.acceleration {
                readings.acceleration.append(Vector3(x: a.x, y: a.y, z: a.z))
            }
            if let r = manager.gyroData?.rotationRate {
                readings.rotation.append(Vector3(x: r.x, y: r.y, z: r.z))
            }
            progress = min(Date.now.timeIntervalSince(start) / seconds, 1)
        }
        stop()
        return readings
    }

    func stop() {
        manager.stopAccelerometerUpdates()
        manager.stopGyroUpdates()
    }
}
