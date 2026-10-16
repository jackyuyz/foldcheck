import Testing
import Foundation
@testable import TestsKit

@Suite("Latest result per test")
struct LatestResultsTests {
    let t0 = Date(timeIntervalSinceReferenceDate: 3_000_000)

    func session(startedAt offset: TimeInterval, _ results: [(TestID, TestOutcome, TimeInterval)]) -> InspectionSession {
        InspectionSession(
            startedAt: t0.addingTimeInterval(offset),
            deviceModel: "iPhone Duo",
            osVersion: "27.1",
            hasHinge: true,
            results: results.map { TestResult(id: $0.0, outcome: $0.1, finishedAt: t0.addingTimeInterval($0.2)) }
        )
    }

    @Test("Newest measured result wins per test")
    func newestWins() {
        let old = session(startedAt: 0, [(.pixels, .fail, 10), (.hingeSweep, .pass, 20)])
        let new = session(startedAt: 100, [(.pixels, .pass, 110)])

        let latest = InspectionSession.latestResults(in: [new, old])

        #expect(latest[.pixels]?.result.outcome == .pass)
        #expect(latest[.pixels]?.sessionID == new.id)
        #expect(latest[.hingeSweep]?.result.outcome == .pass)
        #expect(latest[.hingeSweep]?.sessionID == old.id)
        #expect(latest[.cameras] == nil)
    }

    @Test("Skipped and not-applicable results don't hide an earlier measurement")
    func unmeasuredIgnoredByDefault() {
        let measured = session(startedAt: 0, [(.hingeSweep, .attention, 10)])
        let skipped = session(startedAt: 100, [(.hingeSweep, .skipped, 110), (.crease, .notApplicable, 110)])

        let latest = InspectionSession.latestResults(in: [measured, skipped])
        #expect(latest[.hingeSweep]?.result.outcome == .attention)
        #expect(latest[.crease] == nil)

        let all = InspectionSession.latestResults(in: [measured, skipped], includeUnmeasured: true)
        #expect(all[.hingeSweep]?.result.outcome == .skipped)
        #expect(all[.crease]?.result.outcome == .notApplicable)
    }

    @Test("Equal finish times fall back to the later session")
    func tieBreak() {
        let first = session(startedAt: 0, [(.audio, .fail, 50)])
        let second = session(startedAt: 10, [(.audio, .pass, 50)])

        #expect(InspectionSession.latestResults(in: [second, first])[.audio]?.sessionID == second.id)
        #expect(InspectionSession.latestResults(in: [first, second])[.audio]?.sessionID == second.id)
    }

    @Test("No sessions gives no results")
    func empty() {
        #expect(InspectionSession.latestResults(in: []).isEmpty)
    }
}
