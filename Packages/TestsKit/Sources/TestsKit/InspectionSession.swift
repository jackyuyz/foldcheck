import Foundation

/// A complete inspection session containing all test results.
public struct InspectionSession: Codable, Sendable, Identifiable, Equatable {
    /// Unique identifier for this session
    public var id: UUID
    
    /// When the inspection started
    public var startedAt: Date
    
    /// Device model (from utsname.machine → friendly name)
    public var deviceModel: String
    
    /// iOS version string
    public var osVersion: String
    
    /// Device storage capacity in bytes
    public var storageCapacity: UInt64?
    
    /// Whether the device has a hinge (is a Duo)
    public var hasHinge: Bool
    
    /// Results for each test
    public var results: [TestResult]
    
    /// Path to the generated PDF report file (if any)
    public var reportFile: String?
    
    /// Base64-encoded signature of the report (if signed)
    public var signatureB64: String?
    
    /// When the session was completed
    public var completedAt: Date?
    
    /// Time zone identifier at time of inspection
    public var timeZoneIdentifier: String
    
    public init(
        id: UUID = UUID(),
        startedAt: Date = .now,
        deviceModel: String,
        osVersion: String,
        storageCapacity: UInt64? = nil,
        hasHinge: Bool,
        results: [TestResult] = [],
        reportFile: String? = nil,
        signatureB64: String? = nil,
        completedAt: Date? = nil,
        timeZoneIdentifier: String = TimeZone.current.identifier
    ) {
        self.id = id
        self.startedAt = startedAt
        self.deviceModel = deviceModel
        self.osVersion = osVersion
        self.storageCapacity = storageCapacity
        self.hasHinge = hasHinge
        self.results = results
        self.reportFile = reportFile
        self.signatureB64 = signatureB64
        self.completedAt = completedAt
        self.timeZoneIdentifier = timeZoneIdentifier
    }
    
    // MARK: - Result Management
    
    /// Add or update a test result
    public mutating func setResult(_ result: TestResult) {
        if let index = results.firstIndex(where: { $0.id == result.id }) {
            results[index] = result
        } else {
            results.append(result)
        }
    }
    
    /// Get the result for a specific test
    public func result(for testID: TestID) -> TestResult? {
        results.first(where: { $0.id == testID })
    }
    
    /// Check if a test has been completed (has a result)
    public func isCompleted(_ testID: TestID) -> Bool {
        result(for: testID) != nil
    }
    
    // MARK: - Summary Calculations
    
    /// Count of tests by outcome
    public var outcomeCounts: [TestOutcome: Int] {
        var counts: [TestOutcome: Int] = [:]
        for result in results {
            counts[result.outcome, default: 0] += 1
        }
        return counts
    }
    
    /// Number of tests that passed
    public var passCount: Int {
        outcomeCounts[.pass] ?? 0
    }
    
    /// Number of tests that need attention
    public var attentionCount: Int {
        outcomeCounts[.attention] ?? 0
    }
    
    /// Number of tests that failed
    public var failCount: Int {
        outcomeCounts[.fail] ?? 0
    }
    
    /// Number of tests completed (pass, attention, or fail)
    public var completedCount: Int {
        results.filter { $0.outcome.isCompleted }.count
    }
    
    /// Overall score (average of completed tests, 0-100)
    public var overallScore: Int? {
        let scorableResults = results.filter { $0.outcome.score >= 0 }
        guard !scorableResults.isEmpty else { return nil }
        let total = scorableResults.reduce(0) { $0 + $1.outcome.score }
        return total / scorableResults.count
    }
    
    /// Overall status based on results
    public var overallStatus: TestOutcome {
        if failCount > 0 {
            return .fail
        } else if attentionCount > 0 {
            return .attention
        } else if passCount > 0 {
            return .pass
        } else {
            return .skipped
        }
    }
    
    /// Duration of the inspection in seconds
    public var durationSeconds: TimeInterval? {
        guard let completed = completedAt else { return nil }
        return completed.timeIntervalSince(startedAt)
    }
    
    /// Human-readable duration string
    public var durationString: String? {
        guard let duration = durationSeconds else { return nil }
        let minutes = Int(duration) / 60
        let seconds = Int(duration) % 60
        if minutes > 0 {
            return "\(minutes)m \(seconds)s"
        } else {
            return "\(seconds)s"
        }
    }
}

// MARK: - Device Info Helpers

public extension InspectionSession {
    /// Create a session with current device info
    /// Note: On Linux/non-iOS platforms, this provides placeholder values
    static func create(deviceModel: String = "Unknown", osVersion: String = "Unknown", hasHinge: Bool = false) -> InspectionSession {
        InspectionSession(
            deviceModel: deviceModel,
            osVersion: osVersion,
            hasHinge: hasHinge
        )
    }
}

// MARK: - Storage Formatting

public extension InspectionSession {
    /// Storage capacity formatted as a human-readable string
    var storageCapacityFormatted: String? {
        guard let capacity = storageCapacity else { return nil }
        let formatter = ByteCountFormatter()
        formatter.countStyle = .binary
        return formatter.string(fromByteCount: Int64(capacity))
    }
}
