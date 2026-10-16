import Testing
import Foundation
@testable import TestsKit

@Suite("History compare (F4)")
struct SessionComparisonTests {
    private func session(daysAgo: Double, _ results: [TestResult]) -> InspectionSession {
        var session = InspectionSession(
            startedAt: Date(timeIntervalSinceNow: -daysAgo * 86_400),
            deviceModel: "iPhone Duo",
            osVersion: "iOS 27.1",
            hasHinge: true
        )
        for result in results { session.setResult(result) }
        return session
    }

    @Test("Orders by date and marks each metric better or worse")
    func changes() throws {
        let lastMonth = session(daysAgo: 30, [
            TestResult(id: .hingeSweep, outcome: .pass, metrics: [TestMetricKey.monotonicFraction: 0.98, TestMetricKey.maxGapDegrees: 4]),
            TestResult(id: .crease, outcome: .pass, metrics: [TestMetricKey.creaseRating: 2]),
            TestResult(id: .touchGridInner, outcome: .pass, metrics: [TestMetricKey.missedCells: 0]),
        ])
        let today = session(daysAgo: 0, [
            TestResult(id: .hingeSweep, outcome: .attention, metrics: [TestMetricKey.monotonicFraction: 0.85, TestMetricKey.maxGapDegrees: 25]),
            TestResult(id: .crease, outcome: .pass, metrics: [TestMetricKey.creaseRating: 1.5]),
            TestResult(id: .touchGridInner, outcome: .pass, metrics: [TestMetricKey.missedCells: 0]),
            TestResult(id: .pixels, outcome: .pass),
        ])

        // Either argument order gives the same comparison.
        let comparison = SessionComparison(today, lastMonth)
        #expect(comparison.older.id == lastMonth.id)
        #expect(comparison.rows.map(\.id) == [.touchGridInner, .pixels, .crease, .hingeSweep])

        let hinge = try #require(comparison.rows.first { $0.id == .hingeSweep })
        #expect(hinge.outcomeChange == .worse)
        #expect(hinge.metrics.map(\.change) == [.worse, .worse])

        let crease = try #require(comparison.rows.first { $0.id == .crease })
        #expect(crease.metrics.first?.change == .better)  // lower rating: less visible

        let touch = try #require(comparison.rows.first { $0.id == .touchGridInner })
        #expect(touch.metrics.first?.change == .same)

        let pixels = try #require(comparison.rows.first { $0.id == .pixels })
        #expect(pixels.older == nil)
        #expect(pixels.outcomeChange == .notComparable)
        #expect(comparison.scoreChange == .worse)
    }

    @Test("Skipped and N/A outcomes aren't compared")
    func notScored() {
        let a = session(daysAgo: 2, [TestResult(id: .cameras, outcome: .skipped)])
        let b = session(daysAgo: 1, [TestResult(id: .cameras, outcome: .pass)])
        #expect(SessionComparison(a, b).rows.first?.outcomeChange == .notComparable)
    }
}
