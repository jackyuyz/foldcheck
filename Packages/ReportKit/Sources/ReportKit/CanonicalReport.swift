import Foundation
import TestsKit

/// The canonical JSON representation of a report for signing and verification.
///
/// This structure contains all the data that is signed to ensure tamper-evidence.
/// Changes to this structure will invalidate existing signatures.
public struct CanonicalReport: Codable, Sendable, Equatable {
    /// Report metadata
    public var reportID: UUID
    public var generatedAt: Date
    public var timeZoneIdentifier: String
    public var appVersion: String
    public var reportVersion: Int
    
    /// Device information
    public var deviceModel: String
    public var osVersion: String
    public var storageCapacityBytes: UInt64?
    public var hasHinge: Bool
    
    /// Inspection data
    public var inspectionStartedAt: Date
    public var inspectionCompletedAt: Date?
    public var results: [CanonicalTestResult]
    
    public init(
        reportID: UUID = UUID(),
        generatedAt: Date = .now,
        timeZoneIdentifier: String = TimeZone.current.identifier,
        appVersion: String = "1.0.0",
        reportVersion: Int = 1,
        deviceModel: String,
        osVersion: String,
        storageCapacityBytes: UInt64? = nil,
        hasHinge: Bool,
        inspectionStartedAt: Date,
        inspectionCompletedAt: Date? = nil,
        results: [CanonicalTestResult]
    ) {
        self.reportID = reportID
        self.generatedAt = generatedAt
        self.timeZoneIdentifier = timeZoneIdentifier
        self.appVersion = appVersion
        self.reportVersion = reportVersion
        self.deviceModel = deviceModel
        self.osVersion = osVersion
        self.storageCapacityBytes = storageCapacityBytes
        self.hasHinge = hasHinge
        self.inspectionStartedAt = inspectionStartedAt
        self.inspectionCompletedAt = inspectionCompletedAt
        self.results = results
    }
    
    /// Create from an inspection session
    public static func from(session: InspectionSession, appVersion: String = "1.0.0") -> CanonicalReport {
        CanonicalReport(
            reportID: UUID(),
            generatedAt: .now,
            timeZoneIdentifier: session.timeZoneIdentifier,
            appVersion: appVersion,
            reportVersion: 1,
            deviceModel: session.deviceModel,
            osVersion: session.osVersion,
            storageCapacityBytes: session.storageCapacity,
            hasHinge: session.hasHinge,
            inspectionStartedAt: session.startedAt,
            inspectionCompletedAt: session.completedAt,
            results: session.results.map { CanonicalTestResult.from($0) }
        )
    }
    
    /// Encode to canonical JSON (deterministic, suitable for hashing)
    public func toCanonicalJSON() throws -> Data {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        return try encoder.encode(self)
    }
    
    /// Decode from JSON
    public static func fromJSON(_ data: Data) throws -> CanonicalReport {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try decoder.decode(CanonicalReport.self, from: data)
    }
}

/// Canonical representation of a test result for the signed report
public struct CanonicalTestResult: Codable, Sendable, Equatable {
    public var testID: String
    public var outcome: String
    public var metrics: [String: Double]
    public var notes: String
    public var display: String?
    public var finishedAt: Date
    public var touchHeatmap: TouchHeatmap?
    
    public init(
        testID: String,
        outcome: String,
        metrics: [String: Double],
        notes: String,
        display: String?,
        finishedAt: Date,
        touchHeatmap: TouchHeatmap? = nil
    ) {
        self.testID = testID
        self.outcome = outcome
        self.metrics = metrics
        self.notes = notes
        self.display = display
        self.finishedAt = finishedAt
        self.touchHeatmap = touchHeatmap
    }
    
    public static func from(_ result: TestResult) -> CanonicalTestResult {
        CanonicalTestResult(
            testID: result.id.rawValue,
            outcome: result.outcome.rawValue,
            metrics: result.metrics,
            notes: result.notes,
            display: result.display?.rawValue,
            finishedAt: result.finishedAt,
            touchHeatmap: result.touchHeatmap
        )
    }
}
