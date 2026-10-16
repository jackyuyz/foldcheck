#if DEBUG
import Foundation
import SwiftData
import TestsKit
import Library

/// Deterministic sample data for review screenshots. Only enabled by -ScreenshotFixtures;
/// the app uses an isolated in-memory store, so existing inspections are never replaced.
@MainActor
enum ScreenshotFixtures {
    static func populate(_ container: ModelContainer) throws {
        let library = SessionLibrary(context: ModelContext(container))
        for month in [9, 10] {
            let date = ISO8601DateFormatter().date(from: "2026-\(month == 9 ? "09" : "10")-16T14:00:00Z")!
            var session = InspectionSession(
                startedAt: date, deviceModel: "iPhone Duo (Simulator)", osVersion: "iOS 27.1",
                storageCapacity: 256_000_000_000, hasHinge: true, timeZoneIdentifier: "America/New_York"
            )
            for id in TestID.defaultOrder {
                var result = TestResult(id: id, outcome: .pass, notes: "Sample data / 示例数据", finishedAt: date.addingTimeInterval(240))
                switch id {
                case .touchGridOuter, .touchGridInner:
                    result.display = id == .touchGridInner ? .inner : .outer
                    result.metrics = [TestMetricKey.cellsCovered: 240, TestMetricKey.totalCells: 240,
                                      TestMetricKey.coveragePercent: 100, TestMetricKey.missedCells: 0,
                                      TestMetricKey.maxTouches: 5]
                    if id == .touchGridInner {
                        result.metrics[TestMetricKey.creaseBandCoverage] = 100
                        result.metrics[TestMetricKey.creaseBandMissed] = 0
                    }
                case .pixels:
                    result.metrics = [TestMetricKey.issuesMarked: 0]
                case .crease:
                    result.metrics = [TestMetricKey.creaseRating: month == 9 ? 2 : 3, TestMetricKey.creaseRatingMax: 3]
                case .hingeSweep:
                    result.outcome = month == 9 ? .pass : .attention
                    result.metrics = [TestMetricKey.maxGapDegrees: month == 9 ? 3 : 18,
                                      TestMetricKey.monotonicFraction: 1,
                                      TestMetricKey.observedMinAngle: 20, TestMetricKey.observedMaxAngle: 178,
                                      TestMetricKey.sampleRate: 30, TestMetricKey.restJitter: 0.4]
                    var points: [TestSeriesPoint] = []
                    for n in 0..<120 {
                        let time = Double(n) / 10.0
                        let angle = n < 60 ? 178.0 - Double(n) * 2.6 : 22.0 + Double(n - 60) * 2.6
                        points.append(TestSeriesPoint(t: time, value: angle, segment: 0))
                    }
                    result.series = points
                case .touchID:
                    result.outcome = .unavailable
                case .cameras, .audio, .sensors, .buttons:
                    result.outcome = .skipped
                }
                session.setResult(result)
            }
            session.completedAt = date.addingTimeInterval(240)
            try library.save(session, isFullInspection: true)
        }
    }
}
#endif
