import Foundation
import FoldKit

/// Which display a test was performed on.
public enum DisplayKind: String, Codable, Sendable, Equatable {
    case outer
    case inner
}

/// The result of a single inspection test.
public struct TestResult: Codable, Sendable, Equatable, Identifiable {
    /// The test that produced this result
    public var id: TestID
    
    /// The outcome of the test
    public var outcome: TestOutcome
    
    /// Numeric metrics collected during the test
    /// Keys are metric names, values are the measurements
    public var metrics: [String: Double]
    
    /// User notes or system-generated notes about the test
    public var notes: String
    
    /// Which display the test was run on (if applicable)
    public var display: DisplayKind?
    
    /// Filenames of attachments (photos, recordings) in the report
    public var attachments: [String]
    
    /// When the test was completed
    public var finishedAt: Date
    
    public init(
        id: TestID,
        outcome: TestOutcome,
        metrics: [String: Double] = [:],
        notes: String = "",
        display: DisplayKind? = nil,
        attachments: [String] = [],
        finishedAt: Date = .now
    ) {
        self.id = id
        self.outcome = outcome
        self.metrics = metrics
        self.notes = notes
        self.display = display
        self.attachments = attachments
        self.finishedAt = finishedAt
    }
    
    /// Create a result for a skipped test
    public static func skipped(id: TestID, reason: String = "") -> TestResult {
        TestResult(
            id: id,
            outcome: .skipped,
            notes: reason.isEmpty ? "Test skipped by user" : reason
        )
    }
    
    /// Create a result for a not-applicable test
    public static func notApplicable(id: TestID, reason: String) -> TestResult {
        TestResult(
            id: id,
            outcome: .notApplicable,
            notes: reason
        )
    }
}

// MARK: - Metric Keys

/// Standard metric keys used across tests
public enum TestMetricKey {
    // Touch Grid
    public static let cellsCovered = "cellsCovered"
    public static let totalCells = "totalCells"
    public static let missedCells = "missedCells"
    public static let coveragePercent = "coveragePercent"
    public static let creaseBandCoverage = "creaseBandCoverage"
    public static let maxTouches = "maxTouches"
    
    // Pixels
    public static let issuesMarked = "issuesMarked"
    
    // Crease
    public static let creaseRating = "creaseRating"  // 1-5
    public static let viewingAngles = "viewingAngles"  // count
    
    // Hinge
    public static let observedMinAngle = "observedMinAngle"
    public static let observedMaxAngle = "observedMaxAngle"
    public static let maxGapDegrees = "maxGapDegrees"
    public static let monotonicFraction = "monotonicFraction"
    public static let sampleRate = "sampleRate"
    public static let restJitter = "restJitter"
    
    // Cameras
    public static let camerasAvailable = "camerasAvailable"
    public static let camerasTested = "camerasTested"
    public static let sharpnessScore = "sharpnessScore"
    
    // Audio
    public static let speakerLeftConfirmed = "speakerLeftConfirmed"
    public static let speakerRightConfirmed = "speakerRightConfirmed"
    public static let micPeakLevel = "micPeakLevel"
    
    // TouchID
    public static let biometryAvailable = "biometryAvailable"
    public static let biometryType = "biometryType"
    
    // Sensors
    public static let accelerometerOK = "accelerometerOK"
    public static let gyroscopeOK = "gyroscopeOK"
    public static let hapticConfirmed = "hapticConfirmed"
    
    // Buttons
    public static let volumeUpDetected = "volumeUpDetected"
    public static let volumeDownDetected = "volumeDownDetected"
}
