// ReportKit - Report generation and verification for FoldCheck
// This package provides report data models, content assembly,
// signing/verification, and PDF rendering support.

@_exported import Foundation
@_exported import FoldKit
@_exported import TestsKit

// Re-export all public types
public typealias _ReportEnvelope = ReportEnvelope
public typealias _CanonicalReport = CanonicalReport
public typealias _CanonicalTestResult = CanonicalTestResult
public typealias _ReportContent = ReportContent
public typealias _TestResultContent = TestResultContent
public typealias _ReportContentAssembler = ReportContentAssembler
public typealias _DeviceNames = DeviceNames
public typealias _ReportSigner = ReportSigner
public typealias _SoftwareReportSigner = SoftwareReportSigner
