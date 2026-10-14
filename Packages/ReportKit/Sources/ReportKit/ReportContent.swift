import Foundation
import TestsKit

/// Assembled content for PDF report generation.
///
/// This structure contains all the formatted text and data needed
/// to render a PDF report. The actual PDF rendering is done by
/// platform-specific code (PDFKit/UIGraphicsPDFRenderer on iOS).
public struct ReportContent: Sendable {
    /// Report header
    public var title: String
    public var reportID: String
    public var generatedAt: String
    public var timeZone: String
    
    /// Device information section
    public var deviceModel: String
    public var osVersion: String
    public var storageCapacity: String?
    public var deviceType: String  // "iPhone Duo" or "iPhone"
    
    /// Inspection summary
    public var inspectionDate: String
    public var inspectionDuration: String?
    public var overallStatus: String
    public var overallScore: String?
    
    /// Test results
    public var testResults: [TestResultContent]
    
    /// Disclaimer text
    public var disclaimer: String
    
    /// Signature status
    public var signatureStatus: String
    public var keyFingerprint: String?
    
    /// QR code payload (JSON string)
    public var qrPayload: String?
    
    public init(
        title: String,
        reportID: String,
        generatedAt: String,
        timeZone: String,
        deviceModel: String,
        osVersion: String,
        storageCapacity: String?,
        deviceType: String,
        inspectionDate: String,
        inspectionDuration: String?,
        overallStatus: String,
        overallScore: String?,
        testResults: [TestResultContent],
        disclaimer: String,
        signatureStatus: String,
        keyFingerprint: String?,
        qrPayload: String?
    ) {
        self.title = title
        self.reportID = reportID
        self.generatedAt = generatedAt
        self.timeZone = timeZone
        self.deviceModel = deviceModel
        self.osVersion = osVersion
        self.storageCapacity = storageCapacity
        self.deviceType = deviceType
        self.inspectionDate = inspectionDate
        self.inspectionDuration = inspectionDuration
        self.overallStatus = overallStatus
        self.overallScore = overallScore
        self.testResults = testResults
        self.disclaimer = disclaimer
        self.signatureStatus = signatureStatus
        self.keyFingerprint = keyFingerprint
        self.qrPayload = qrPayload
    }
}

/// Content for a single test result in the report
public struct TestResultContent: Sendable {
    public var testName: String
    public var outcome: String
    public var outcomeColor: String
    public var metrics: [(name: String, value: String)]
    public var notes: String?
    public var display: String?
    
    public init(
        testName: String,
        outcome: String,
        outcomeColor: String,
        metrics: [(name: String, value: String)],
        notes: String?,
        display: String?
    ) {
        self.testName = testName
        self.outcome = outcome
        self.outcomeColor = outcomeColor
        self.metrics = metrics
        self.notes = notes
        self.display = display
    }
}

// MARK: - Content Assembly

public struct ReportContentAssembler {
    private let dateFormatter: DateFormatter
    private let timeFormatter: DateFormatter
    
    public init() {
        dateFormatter = DateFormatter()
        dateFormatter.dateStyle = .long
        dateFormatter.timeStyle = .none
        
        timeFormatter = DateFormatter()
        timeFormatter.dateStyle = .long
        timeFormatter.timeStyle = .medium
    }
    
    /// Assemble report content from a session and envelope
    public func assemble(
        session: InspectionSession,
        envelope: ReportEnvelope?
    ) -> ReportContent {
        let deviceType = session.hasHinge ? "iPhone Duo" : "iPhone"
        
        let testResults = session.results.map { result in
            TestResultContent(
                testName: result.id.displayName,
                outcome: result.outcome.displayName,
                outcomeColor: result.outcome.colorName,
                metrics: formatMetrics(result.metrics, for: result.id),
                notes: result.notes.isEmpty ? nil : result.notes,
                display: result.display?.rawValue.capitalized
            )
        }
        
        let signatureStatus: String
        let keyFingerprint: String?
        
        if let env = envelope {
            if env.isDevelopmentBuild {
                signatureStatus = "Development build (unsigned)"
                keyFingerprint = nil
            } else {
                signatureStatus = "Signed on this device"
                keyFingerprint = env.keyFingerprint
            }
        } else {
            signatureStatus = "Not signed"
            keyFingerprint = nil
        }
        
        return ReportContent(
            title: "FoldCheck Inspection Report",
            reportID: envelope?.reportID.uuidString ?? session.id.uuidString,
            generatedAt: timeFormatter.string(from: Date()),
            timeZone: session.timeZoneIdentifier,
            deviceModel: session.deviceModel,
            osVersion: session.osVersion,
            storageCapacity: session.storageCapacityFormatted,
            deviceType: deviceType,
            inspectionDate: dateFormatter.string(from: session.startedAt),
            inspectionDuration: session.durationString,
            overallStatus: session.overallStatus.displayName,
            overallScore: session.overallScore.map { "\($0)/100" },
            testResults: testResults,
            disclaimer: Self.disclaimer,
            signatureStatus: signatureStatus,
            keyFingerprint: keyFingerprint,
            qrPayload: try? envelope?.toQRPayload()
        )
    }
    
    private func formatMetrics(_ metrics: [String: Double], for testID: TestID) -> [(name: String, value: String)] {
        metrics.map { key, value in
            let formattedValue: String
            let displayName: String
            
            switch key {
            case TestMetricKey.coveragePercent:
                displayName = "Coverage"
                formattedValue = String(format: "%.1f%%", value)
            case TestMetricKey.maxGapDegrees:
                displayName = "Max Gap"
                formattedValue = String(format: "%.1f°", value)
            case TestMetricKey.monotonicFraction:
                displayName = "Continuity"
                formattedValue = String(format: "%.0f%%", value * 100)
            case TestMetricKey.sampleRate:
                displayName = "Sample Rate"
                formattedValue = String(format: "%.0f Hz", value)
            case TestMetricKey.creaseRating:
                displayName = "Crease Rating"
                formattedValue = String(format: "%.0f/5", value)
            case TestMetricKey.observedMinAngle:
                displayName = "Min Angle"
                formattedValue = String(format: "%.1f°", value)
            case TestMetricKey.observedMaxAngle:
                displayName = "Max Angle"
                formattedValue = String(format: "%.1f°", value)
            default:
                displayName = key.replacingOccurrences(of: "([A-Z])", with: " $1", options: .regularExpression).capitalized
                formattedValue = String(format: "%.2f", value)
            }
            
            return (name: displayName, value: formattedValue)
        }.sorted { $0.name < $1.name }
    }
    
    /// Standard disclaimer text
    public static let disclaimer = """
    DISCLAIMER: This report is a user-generated inspection snapshot created by FoldCheck. \
    It is NOT an official certification from Apple or any authorized service provider. \
    The digital signature proves only that this PDF has not been modified since creation by \
    this specific FoldCheck installation. It does not verify device authenticity, ownership, \
    or repair history. FoldCheck cannot access battery health, cycle counts, serial numbers, \
    or lifetime fold counts. The fold counter tracks only folds observed while the app was \
    running in the foreground. Hinge test results reflect continuity and consistency of \
    angle readings, not absolute mechanical accuracy. Use this report as supplementary \
    information only.
    """
}
