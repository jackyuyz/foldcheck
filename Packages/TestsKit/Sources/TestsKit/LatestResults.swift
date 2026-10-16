import Foundation

/// The most recent result of one test across saved sessions, with the session it came from.
public struct LatestTestResult: Sendable, Equatable {
    public var result: TestResult
    public var sessionID: UUID
    public var sessionStartedAt: Date

    public init(result: TestResult, sessionID: UUID, sessionStartedAt: Date) {
        self.result = result
        self.sessionID = sessionID
        self.sessionStartedAt = sessionStartedAt
    }
}

public extension InspectionSession {
    /// Latest result per test across `sessions`, newest `finishedAt` first (session start breaks ties).
    ///
    /// By default only measured outcomes (pass, attention, fail) count, so a later skip or a
    /// quick test that marked a test not applicable doesn't hide the last real measurement.
    /// Tests that never produced a counted result are absent from the dictionary.
    static func latestResults(
        in sessions: [InspectionSession],
        includeUnmeasured: Bool = false
    ) -> [TestID: LatestTestResult] {
        var latest: [TestID: LatestTestResult] = [:]
        for session in sessions {
            for result in session.results where includeUnmeasured || result.outcome.isCompleted {
                let candidate = LatestTestResult(result: result, sessionID: session.id, sessionStartedAt: session.startedAt)
                if let current = latest[result.id], !candidate.isNewer(than: current) { continue }
                latest[result.id] = candidate
            }
        }
        return latest
    }
}

extension LatestTestResult {
    func isNewer(than other: LatestTestResult) -> Bool {
        if result.finishedAt != other.result.finishedAt {
            return result.finishedAt > other.result.finishedAt
        }
        return sessionStartedAt > other.sessionStartedAt
    }
}
