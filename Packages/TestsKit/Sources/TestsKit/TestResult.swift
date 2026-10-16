import Foundation
import FoldKit

/// Which display a test was performed on.
public enum DisplayKind: String, Codable, Sendable, Equatable {
    case outer
    case inner
}

/// One point of a chart series stored with a result (e.g. hinge angle over time).
public struct TestSeriesPoint: Codable, Sendable, Equatable {
    /// Seconds since the segment started (each segment starts at 0).
    public var t: Double
    public var value: Double
    /// Which part of the test the point belongs to (e.g. sweep 1, sweep 2, hold).
    public var segment: Int

    public init(t: Double, value: Double, segment: Int = 0) {
        self.t = t
        self.value = value
        self.segment = segment
    }
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

    /// Downsampled chart data (hinge sweep plot); empty for most tests.
    public var series: [TestSeriesPoint]
    
    public init(
        id: TestID,
        outcome: TestOutcome,
        metrics: [String: Double] = [:],
        notes: String = "",
        display: DisplayKind? = nil,
        attachments: [String] = [],
        finishedAt: Date = .now,
        series: [TestSeriesPoint] = []
    ) {
        self.id = id
        self.outcome = outcome
        self.metrics = metrics
        self.notes = notes
        self.display = display
        self.attachments = attachments
        self.finishedAt = finishedAt
        self.series = series
    }

    enum CodingKeys: String, CodingKey {
        case id, outcome, metrics, notes, display, attachments, finishedAt, series
    }

    /// Results saved before `series` existed decode with an empty series.
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(TestID.self, forKey: .id)
        outcome = try container.decode(TestOutcome.self, forKey: .outcome)
        metrics = try container.decode([String: Double].self, forKey: .metrics)
        notes = try container.decode(String.self, forKey: .notes)
        display = try container.decodeIfPresent(DisplayKind.self, forKey: .display)
        attachments = try container.decode([String].self, forKey: .attachments)
        finishedAt = try container.decode(Date.self, forKey: .finishedAt)
        series = try container.decodeIfPresent([TestSeriesPoint].self, forKey: .series) ?? []
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
    /// 1 for physical single-cell tapping; 0 for the interpolated swipe grid.
    public static let tapMode = "tapMode"
    // Touch Grid
    public static let cellsCovered = "cellsCovered"
    public static let totalCells = "totalCells"
    public static let missedCells = "missedCells"
    public static let coveragePercent = "coveragePercent"
    public static let creaseBandCoverage = "creaseBandCoverage"
    public static let maxTouches = "maxTouches"
    public static let creaseBandCells = "creaseBandCells"
    public static let creaseBandMissed = "creaseBandMissed"
    public static let cellSizePoints = "cellSizePoints"
    public static let orientationLandscape = "orientationLandscape"
    /// 1 when the user said a case blocks the missed cells, 0 when they said areas don't respond.
    public static let missReasonBlockedByCase = "missReasonBlockedByCase"
    
    // Pixels
    public static let issuesMarked = "issuesMarked"
    public static let patternsShown = "patternsShown"
    public static func pixelIssues(_ pattern: PixelTestPattern) -> String { "issues.\(pattern.rawValue)" }
    public static func pixelMarkX(_ n: Int) -> String { "mark\(n).x" }
    public static func pixelMarkY(_ n: Int) -> String { "mark\(n).y" }
    /// Index into `PixelTestPattern.allCases`.
    public static func pixelMarkPattern(_ n: Int) -> String { "mark\(n).pattern" }
    
    // Crease
    public static let creaseRating = "creaseRating"  // 1-5
    public static let viewingAngles = "viewingAngles"  // count
    public static let creaseRatingMax = "creaseRatingMax"
    public static let photoAttached = "photoAttached"
    public static func creaseRating(_ view: CreaseViewingAngle) -> String { "creaseRating.view\(view.rawValue)" }
    public static func creaseHingeAngle(_ view: CreaseViewingAngle) -> String { "hingeAngle.view\(view.rawValue)" }
    
    // Hinge
    public static let observedMinAngle = "observedMinAngle"
    public static let observedMaxAngle = "observedMaxAngle"
    public static let maxGapDegrees = "maxGapDegrees"
    public static let monotonicFraction = "monotonicFraction"
    public static let sampleRate = "sampleRate"
    public static let restJitter = "restJitter"
    public static let holdDrift = "holdDrift"
    public static let holdAngle = "holdAngle"
    public static let hingeSamples = "hingeSamples"
    public static let legCount = "legCount"
    public static let maxBacktrack = "maxBacktrack"
    public static let samplesPer10Degrees = "samplesPer10Degrees"
    /// 1 when any angle came from the on-screen slider instead of the hinge.
    public static let manualInput = "manualInput"
    
    // Cameras (n is the camera's position in the discovery order)
    public static let camerasAvailable = "camerasAvailable"
    public static let camerasTested = "camerasTested"
    /// 1 when the picture looked right, 0 when it looked wrong or no frame arrived.
    public static func cameraOK(_ n: Int) -> String { "camera\(n).ok" }
    public static func cameraBrightness(_ n: Int) -> String { "camera\(n).brightness" }
    public static func cameraSharpness(_ n: Int) -> String { "camera\(n).sharpness" }

    // Audio
    public static let speakerLeftConfirmed = "speakerLeftConfirmed"
    public static let speakerRightConfirmed = "speakerRightConfirmed"
    /// Loudest level during the recording, dBFS.
    public static let micPeakLevel = "micPeakLevel"
    public static let micPlaybackConfirmed = "micPlaybackConfirmed"

    // TouchID
    public static let biometryAvailable = "biometryAvailable"

    // Sensors: 1 OK, 0 not confirmed or faulty; missing when unavailable
    public static func sensorOK(_ part: SensorPart) -> String { "\(part.rawValue)OK" }

    // Buttons
    public static let volumeUpDetected = "volumeUpDetected"
    public static let volumeDownDetected = "volumeDownDetected"
    public static func buttonWorks(_ button: PhysicalButton) -> String { "\(button.rawValue)ButtonWorks" }
}
