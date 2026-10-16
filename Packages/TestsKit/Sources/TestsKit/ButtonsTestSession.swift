import Foundation

/// Hardware buttons apps can't observe; the user checks them off (T9).
public enum PhysicalButton: String, Codable, Sendable, CaseIterable, Equatable {
    case side, action, cameraControl
}

/// The user's answer for one checklist button.
public enum ButtonAnswer: String, Codable, Sendable, Equatable {
    case works, doesNotWork, notOnThisPhone
}

/// Volume button detection plus the manual checklist (T9).
public struct ButtonsTestSession: Sendable, Equatable {
    public enum VolumeDirection: String, Codable, Sendable, Equatable {
        case up, down
    }

    /// `nil` until that button's step ran; `false` when the user gave up waiting.
    public var volumeUpDetected: Bool?
    public var volumeDownDetected: Bool?
    public var checklist: [PhysicalButton: ButtonAnswer] = [:]

    public init() {}

    /// Which way the system volume moved, ignoring changes too small to be a button press.
    public static func direction(from old: Double, to new: Double) -> VolumeDirection? {
        let delta = new - old
        guard abs(delta) >= 0.01 else { return nil }
        return delta > 0 ? .up : .down
    }

    /// The order to ask for the volume buttons: at full volume "up" can't change anything,
    /// so ask for "down" first, and the other way round at zero.
    public static func order(startingVolume: Double) -> [VolumeDirection] {
        startingVolume <= 0.01 ? [.up, .down] : [.down, .up]
    }

    public mutating func record(_ detected: Bool, for direction: VolumeDirection) {
        switch direction {
        case .up: volumeUpDetected = detected
        case .down: volumeDownDetected = detected
        }
    }

    /// Both volume buttons detected and nothing on the checklist marked broken is Pass.
    /// A button that wasn't detected or that the user says doesn't work is Attention: the
    /// detection depends on the audio system, so FoldCheck doesn't call it a hardware fault.
    public var outcome: TestOutcome {
        let volumeOK = volumeUpDetected == true && volumeDownDetected == true
        let checklistOK = !checklist.values.contains(.doesNotWork)
        return volumeOK && checklistOK ? .pass : .attention
    }

    public func result(notes: String = "", finishedAt: Date = .now) -> TestResult {
        var metrics: [String: Double] = [:]
        if let volumeUpDetected { metrics[TestMetricKey.volumeUpDetected] = volumeUpDetected ? 1 : 0 }
        if let volumeDownDetected { metrics[TestMetricKey.volumeDownDetected] = volumeDownDetected ? 1 : 0 }
        for (button, answer) in checklist where answer != .notOnThisPhone {
            metrics[TestMetricKey.buttonWorks(button)] = answer == .works ? 1 : 0
        }
        return TestResult(id: .buttons, outcome: outcome, metrics: metrics, notes: notes, finishedAt: finishedAt)
    }
}
