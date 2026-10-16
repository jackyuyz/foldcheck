import Foundation
import FoldL10n
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
    
    /// Assemble report content from a session and envelope.
    /// `language` defaults to English. Pass the app language, or English when the user wants a resale report.
    public func assemble(
        session: InspectionSession,
        envelope: ReportEnvelope?,
        language: AppLanguage = .en,
        generatedAt: Date = .now
    ) -> ReportContent {
        dateFormatter.locale = Locale(identifier: language.localeIdentifier)
        timeFormatter.locale = Locale(identifier: language.localeIdentifier)

        let deviceType = session.hasHinge
            ? L10nKey.reportIphoneDuo.text(in: language)
            : L10nKey.reportIphone.text(in: language)
        
        let testResults = session.results.map { result in
            TestResultContent(
                testName: localizedCopy(result.id.nameKey(hasHinge: session.hasHinge), language: language),
                outcome: localizedCopy("outcome.\(result.outcome.rawValue)", language: language),
                outcomeColor: result.outcome.colorName,
                metrics: formatMetrics(result.metrics, language: language),
                notes: result.notes.isEmpty ? nil : result.notes,
                display: result.display.map { localizedCopy("display.\($0.rawValue)", language: language) }
            )
        }
        
        let signatureStatus: String
        let keyFingerprint: String?
        
        if let env = envelope {
            if env.isDevelopmentBuild {
                signatureStatus = L10nKey.reportDevUnsigned.text(in: language)
                keyFingerprint = nil
            } else {
                signatureStatus = L10nKey.reportSignedOnDevice.text(in: language)
                keyFingerprint = env.keyFingerprint
            }
        } else {
            signatureStatus = L10nKey.reportNotSigned.text(in: language)
            keyFingerprint = nil
        }
        
        return ReportContent(
            title: L10nKey.reportTitle.text(in: language),
            reportID: envelope?.reportID.uuidString ?? session.id.uuidString,
            generatedAt: timeFormatter.string(from: generatedAt),
            timeZone: session.timeZoneIdentifier,
            deviceModel: session.deviceModel,
            osVersion: session.osVersion,
            storageCapacity: session.storageCapacityFormatted,
            deviceType: deviceType,
            inspectionDate: dateFormatter.string(from: session.startedAt),
            inspectionDuration: session.durationString,
            overallStatus: localizedCopy("outcome.\(session.overallStatus.rawValue)", language: language),
            overallScore: session.overallScore.map { "\($0)/100" },
            testResults: testResults,
            disclaimer: L10nKey.reportDisclaimer.text(in: language),
            signatureStatus: signatureStatus,
            keyFingerprint: keyFingerprint,
            qrPayload: try? envelope?.toQRPayload()
        )
    }
    
    private func formatMetrics(_ metrics: [String: Double], language: AppLanguage) -> [(name: String, value: String)] {
        metrics.map { key, value in
            let formattedValue: String
            let displayName: String
            
            switch key {
            case TestMetricKey.coveragePercent:
                displayName = L10nKey.metricCoverage.text(in: language)
                formattedValue = String(format: "%.1f%%", value)
            case TestMetricKey.maxGapDegrees:
                displayName = L10nKey.metricMaxGap.text(in: language)
                formattedValue = String(format: "%.1f°", value)
            case TestMetricKey.monotonicFraction:
                displayName = L10nKey.metricContinuity.text(in: language)
                formattedValue = String(format: "%.0f%%", value * 100)
            case TestMetricKey.sampleRate:
                displayName = L10nKey.metricSampleRate.text(in: language)
                formattedValue = String(format: "%.0f Hz", value)
            case TestMetricKey.creaseRating:
                displayName = L10nKey.metricCreaseRating.text(in: language)
                formattedValue = String(format: "%.0f/5", value)
            case TestMetricKey.observedMinAngle:
                displayName = L10nKey.metricMinAngle.text(in: language)
                formattedValue = String(format: "%.1f°", value)
            case TestMetricKey.observedMaxAngle:
                displayName = L10nKey.metricMaxAngle.text(in: language)
                formattedValue = String(format: "%.1f°", value)
            default:
                displayName = key.replacingOccurrences(of: "([A-Z])", with: " $1", options: .regularExpression).capitalized
                formattedValue = String(format: "%.2f", value)
            }
            
            return (name: displayName, value: formattedValue)
        }.sorted { $0.name < $1.name }
    }
    
    /// English disclaimer. Localized reports use `L10nKey.reportDisclaimer`.
    public static var disclaimer: String {
        L10nKey.reportDisclaimer.text(in: .en)
    }
}
