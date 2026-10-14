import Foundation

/// The outcome of an inspection test.
public enum TestOutcome: String, Codable, Sendable, Equatable {
    /// Test completed successfully with no issues
    case pass
    
    /// Test completed but found minor issues or concerns
    case attention
    
    /// Test completed but found significant issues
    case fail
    
    /// Test was skipped by the user
    case skipped
    
    /// Test is not applicable on this device (e.g., hinge tests on non-Duo)
    case notApplicable

    /// The test applies but couldn't measure anything (e.g., no hinge readings arrived on a Duo).
    /// Never a failure: it reflects an API or data gap, not the device.
    case unavailable
    
    /// Human-readable display name
    public var displayName: String {
        switch self {
        case .pass: return "Pass"
        case .attention: return "Attention"
        case .fail: return "Fail"
        case .skipped: return "Skipped"
        case .notApplicable: return "Not Applicable"
        case .unavailable: return "Unavailable"
        }
    }
    
    /// Whether this outcome indicates a successful completion
    public var isCompleted: Bool {
        switch self {
        case .pass, .attention, .fail:
            return true
        case .skipped, .notApplicable, .unavailable:
            return false
        }
    }
    
    /// Color name for UI display (semantic)
    public var colorName: String {
        switch self {
        case .pass: return "green"
        case .attention: return "amber"
        case .fail: return "red"
        case .skipped: return "gray"
        case .notApplicable: return "gray"
        case .unavailable: return "gray"
        }
    }
    
    /// SF Symbol name for the outcome
    public var iconName: String {
        switch self {
        case .pass: return "checkmark.circle.fill"
        case .attention: return "exclamationmark.triangle.fill"
        case .fail: return "xmark.circle.fill"
        case .skipped: return "forward.fill"
        case .notApplicable: return "minus.circle.fill"
        case .unavailable: return "questionmark.circle.fill"
        }
    }
    
    /// Numerical score for aggregation (higher is better)
    public var score: Int {
        switch self {
        case .pass: return 100
        case .attention: return 70
        case .fail: return 0
        case .skipped: return -1  // Not counted
        case .notApplicable: return -1  // Not counted
        case .unavailable: return -1  // Not counted
        }
    }
}
