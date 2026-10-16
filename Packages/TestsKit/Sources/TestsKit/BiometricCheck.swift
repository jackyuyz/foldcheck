import Foundation

/// What a Touch ID check (T7) ended with. The app maps `LAError` codes to these, so the
/// outcome rules stay testable without LocalAuthentication.
public enum BiometricCheck: String, Codable, Sendable, Equatable {
    /// The finger matched.
    case matched
    /// Touch ID works but no finger is enrolled.
    case notEnrolled
    /// Too many failed attempts; the passcode is needed first.
    case lockedOut
    /// The user tried and the finger didn't match.
    case notMatched
    /// The sensor isn't available (hardware error or not present).
    case unavailable

    /// Matched is Pass and a failed match is Fail. Not enrolled and locked out are Attention:
    /// they block the test without saying anything about the sensor.
    public var outcome: TestOutcome {
        switch self {
        case .matched: return .pass
        case .notEnrolled, .lockedOut: return .attention
        case .notMatched: return .fail
        case .unavailable: return .unavailable
        }
    }

    public func result(notes: String = "", finishedAt: Date = .now) -> TestResult {
        TestResult(
            id: .touchID,
            outcome: outcome,
            metrics: [TestMetricKey.biometryAvailable: self == .unavailable ? 0 : 1],
            notes: notes,
            finishedAt: finishedAt
        )
    }
}
