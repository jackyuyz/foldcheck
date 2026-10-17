import Foundation

/// A part of the phone shown on the health dashboard, and the tests that measure it.
public enum HealthComponent: String, CaseIterable, Sendable, Identifiable {
    case hinge, crease, screen, touch, cameras, audio, touchID, sensors, buttons

    public var id: String { rawValue }

    public var tests: [TestID] {
        switch self {
        case .hinge: return [.hingeSweep]
        case .crease: return [.crease]
        case .screen: return [.pixels]
        case .touch: return [.touchGridOuter, .touchGridInner]
        case .cameras: return [.cameras]
        case .audio: return [.audio]
        case .touchID: return [.touchID]
        case .sensors: return [.sensors]
        case .buttons: return [.buttons]
        }
    }

    /// Whether the dashboard shows this part on a device. Same rules as the inspection plan.
    public func applies(to context: DeviceContext) -> Bool {
        tests.contains { $0.isApplicable(context) }
    }
}

/// Design A's dashboard: each part's latest measured result across saved inspections, and an
/// overall score and status from those. Skips and N/A never hide an earlier measurement.
public struct DeviceHealth: Sendable {
    public struct Item: Sendable, Identifiable {
        public var component: HealthComponent
        /// Worst of the component's latest measured results; nil when never measured.
        public var outcome: TestOutcome?
        /// The result that set `outcome` (the worse one for touch: outer and inner grids).
        public var result: TestResult?
        public var checkedAt: Date?

        public var id: HealthComponent { component }
    }

    public let items: [Item]

    public init(sessions: [InspectionSession], context: DeviceContext) {
        let latest = InspectionSession.latestResults(in: sessions)
        items = HealthComponent.allCases.filter { $0.applies(to: context) }.map { component in
            let measured = component.tests.compactMap { latest[$0] }
            // Worst outcome first; among equals, the newest.
            let worst = measured.min { a, b in
                if a.result.outcome.score != b.result.outcome.score {
                    return a.result.outcome.score < b.result.outcome.score
                }
                return a.isNewer(than: b)
            }
            return Item(
                component: component,
                outcome: worst?.result.outcome,
                result: worst?.result,
                checkedAt: measured.map(\.result.finishedAt).max()
            )
        }
    }

    public var measured: [Item] { items.filter { $0.outcome != nil } }

    public var hasData: Bool { !measured.isEmpty }

    /// Mean of the measured parts' scores (Pass 100, Attention 70, Fail 0), like a session score.
    public var score: Int? {
        let scores = measured.compactMap { $0.outcome?.score }
        guard !scores.isEmpty else { return nil }
        return scores.reduce(0, +) / scores.count
    }

    /// Fail if any part failed, Attention if any needs it, otherwise Pass.
    public var status: TestOutcome? {
        let outcomes = measured.compactMap(\.outcome)
        guard !outcomes.isEmpty else { return nil }
        if outcomes.contains(.fail) { return .fail }
        if outcomes.contains(.attention) { return .attention }
        return .pass
    }

    /// Parts at Attention or Fail.
    public var needsAttention: [Item] {
        measured.filter { $0.outcome == .attention || $0.outcome == .fail }
    }

    public var notMeasured: [Item] { items.filter { $0.outcome == nil } }

    public var lastCheckedAt: Date? { measured.compactMap(\.checkedAt).max() }
}
