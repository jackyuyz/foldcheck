import Foundation

/// F4: two saved inspections side by side, older first. For each test that either one ran,
/// the two outcomes and the metrics that show wear over time (touch misses, crease rating,
/// hinge continuity, ...), each marked better, worse, or the same.
public struct SessionComparison: Sendable {
    public enum Change: Sendable, Equatable {
        case better, worse, same
        /// Only one of the two inspections has the value.
        case notComparable
    }

    public struct MetricChange: Sendable, Equatable {
        public var key: String
        public var older: Double?
        public var newer: Double?
        public var change: Change
    }

    public struct Row: Sendable, Equatable, Identifiable {
        public var id: TestID
        public var older: TestOutcome?
        public var newer: TestOutcome?
        public var outcomeChange: Change
        public var metrics: [MetricChange]
    }

    /// The compared metrics per test, and whether a higher value is better.
    public static let comparedMetrics: [TestID: [(key: String, higherIsBetter: Bool)]] = [
        .touchGridOuter: [(TestMetricKey.missedCells, false), (TestMetricKey.coveragePercent, true)],
        .touchGridInner: [(TestMetricKey.missedCells, false), (TestMetricKey.coveragePercent, true), (TestMetricKey.creaseBandMissed, false)],
        .pixels: [(TestMetricKey.issuesMarked, false)],
        .crease: [(TestMetricKey.creaseRating, false)],
        .hingeSweep: [(TestMetricKey.monotonicFraction, true), (TestMetricKey.maxGapDegrees, false)],
    ]

    public let older: InspectionSession
    public let newer: InspectionSession
    public let rows: [Row]

    /// Orders the two sessions by start time, whichever order they're passed in.
    public init(_ first: InspectionSession, _ second: InspectionSession) {
        let (older, newer) = first.startedAt <= second.startedAt ? (first, second) : (second, first)
        self.older = older
        self.newer = newer
        rows = TestID.defaultOrder.compactMap { id in
            let a = older.results.first { $0.id == id }
            let b = newer.results.first { $0.id == id }
            guard a != nil || b != nil else { return nil }
            let metrics = (Self.comparedMetrics[id] ?? []).compactMap { metric -> MetricChange? in
                let old = a?.metrics[metric.key]
                let new = b?.metrics[metric.key]
                guard old != nil || new != nil else { return nil }
                return MetricChange(key: metric.key, older: old, newer: new, change: Self.change(old, new, higherIsBetter: metric.higherIsBetter))
            }
            return Row(id: id, older: a?.outcome, newer: b?.outcome, outcomeChange: Self.change(a?.outcome, b?.outcome), metrics: metrics)
        }
    }

    /// Change in the overall score (newer minus older), when both have one.
    public var scoreChange: Change {
        Self.change(older.overallScore.map(Double.init), newer.overallScore.map(Double.init), higherIsBetter: true)
    }

    static func change(_ older: Double?, _ newer: Double?, higherIsBetter: Bool) -> Change {
        guard let older, let newer else { return .notComparable }
        // Tolerates float noise in stored metrics.
        if abs(newer - older) < 0.0001 { return .same }
        return (newer > older) == higherIsBetter ? .better : .worse
    }

    /// Outcomes compare by their score; Skipped, N/A and Unavailable aren't comparable.
    static func change(_ older: TestOutcome?, _ newer: TestOutcome?) -> Change {
        guard let older, let newer, older.score >= 0, newer.score >= 0 else { return .notComparable }
        return change(Double(older.score), Double(newer.score), higherIsBetter: true)
    }
}
