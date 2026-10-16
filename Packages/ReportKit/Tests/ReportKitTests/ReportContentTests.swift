import Testing
import Foundation
@testable import ReportKit
import FoldL10n
import TestsKit

@Suite("ReportContent Tests")
struct ReportContentTests {
    
    @Test("ReportContentAssembler creates content from session")
    func testAssembleContent() {
        let assembler = ReportContentAssembler()
        
        var session = InspectionSession(
            deviceModel: "iPhone 19 Duo",
            osVersion: "iOS 27.0",
            storageCapacity: 256_000_000_000,
            hasHinge: true
        )
        session.setResult(TestResult(
            id: .touchGridOuter,
            outcome: .pass,
            metrics: [TestMetricKey.coveragePercent: 98.5]
        ))
        session.setResult(TestResult(
            id: .hingeSweep,
            outcome: .attention,
            metrics: [
                TestMetricKey.maxGapDegrees: 15.5,
                TestMetricKey.monotonicFraction: 0.95
            ],
            notes: "Some gaps observed"
        ))
        session.completedAt = Date()
        
        let content = assembler.assemble(session: session, envelope: nil)
        
        #expect(content.title == "FoldCheck Inspection Report")
        #expect(content.deviceModel == "iPhone 19 Duo")
        #expect(content.deviceType == "iPhone Duo")
        #expect(content.testResults.count == 2)
        #expect(content.signatureStatus == "Not signed")
    }
    
    @Test("ReportContentAssembler handles non-Duo device")
    func testAssembleNonDuo() {
        let assembler = ReportContentAssembler()
        
        let session = InspectionSession(
            deviceModel: "iPhone 18",
            osVersion: "iOS 27.0",
            hasHinge: false
        )
        
        let content = assembler.assemble(session: session, envelope: nil)
        
        #expect(content.deviceType == "iPhone")
    }
    
    @Test("ReportContentAssembler formats metrics correctly")
    func testMetricFormatting() {
        let assembler = ReportContentAssembler()
        
        var session = InspectionSession(
            deviceModel: "iPhone 19 Duo",
            osVersion: "iOS 27.0",
            hasHinge: true
        )
        session.setResult(TestResult(
            id: .hingeSweep,
            outcome: .pass,
            metrics: [
                TestMetricKey.coveragePercent: 98.5,
                TestMetricKey.maxGapDegrees: 5.0,
                TestMetricKey.monotonicFraction: 0.98,
                TestMetricKey.sampleRate: 30.0,
                TestMetricKey.creaseRating: 4.0
            ]
        ))
        
        let content = assembler.assemble(session: session, envelope: nil)
        let hingeResult = content.testResults.first { $0.testName == "Hinge Sweep" }
        
        #expect(hingeResult != nil)
        
        let metrics = hingeResult!.metrics
        #expect(metrics.contains { $0.value.contains("°") })  // Angle metrics have degree symbol
        #expect(metrics.contains { $0.value.contains("%") })  // Percentage metrics
        #expect(metrics.contains { $0.value.contains("Hz") }) // Sample rate has Hz
    }
    
    @Test("ReportContentAssembler includes signature info for signed reports")
    func testSignatureInfo() async throws {
        let assembler = ReportContentAssembler()
        let signer = SoftwareReportSigner()
        
        var session = InspectionSession(
            deviceModel: "iPhone 19 Duo",
            osVersion: "iOS 27.0",
            hasHinge: true
        )
        session.setResult(TestResult(id: .touchGridOuter, outcome: .pass))
        
        let report = CanonicalReport.from(session: session)
        let envelope = try await signReport(report, signer: signer)
        
        let content = assembler.assemble(session: session, envelope: envelope)
        
        #expect(content.signatureStatus == "Development build (unsigned)")
        #expect(content.qrPayload != nil)
        #expect(!content.qrPayload!.isEmpty)
    }
    
    @Test("Reports follow the selected language and default to English")
    func testLocalizedAssemble() {
        let assembler = ReportContentAssembler()
        var session = InspectionSession(
            deviceModel: "iPhone 19 Duo",
            osVersion: "iOS 27.0",
            hasHinge: true
        )
        session.setResult(TestResult(id: .hingeSweep, outcome: .pass))

        let english = assembler.assemble(session: session, envelope: nil)
        #expect(english.title == "FoldCheck Inspection Report")
        #expect(english.testResults.first?.testName == "Hinge Sweep")
        #expect(english.overallStatus == "Pass")

        let chinese = assembler.assemble(session: session, envelope: nil, language: .zhHans)
        #expect(chinese.title == "FoldCheck 体检报告")
        #expect(chinese.title != english.title)
        #expect(chinese.disclaimer.contains("声明"))
        #expect(chinese.testResults.first?.testName == "铰链扫掠")
        #expect(chinese.overallStatus == "通过")
        #expect(chinese.deviceType == "iPhone Duo")
    }

    @Test("Disclaimer text is not empty")
    func testDisclaimerText() {
        #expect(!ReportContentAssembler.disclaimer.isEmpty)
        #expect(ReportContentAssembler.disclaimer.contains("DISCLAIMER"))
        #expect(ReportContentAssembler.disclaimer.contains("NOT an official certification"))
    }
}

@Suite("DeviceNames Tests")
struct DeviceNamesTests {
    
    @Test("Known devices return friendly names")
    func testKnownDevices() {
        #expect(DeviceNames.friendlyName(for: "iPhone19,4") == "iPhone Duo")
        #expect(DeviceNames.friendlyName(for: "iPhone19,2") == "iPhone 18 Pro")
        #expect(DeviceNames.friendlyName(for: "iPhone17,1") == "iPhone 16 Pro")
        #expect(DeviceNames.friendlyName(for: "iPhone18,1") == "iPhone 17 Pro")
        #expect(DeviceNames.friendlyName(for: "x86_64") == "Simulator (Intel)")
    }
    
    @Test("Unknown iPhones return formatted fallback")
    func testUnknownIPhone() {
        let name = DeviceNames.friendlyName(for: "iPhone99,9")
        #expect(name == "iPhone (iPhone99,9)")
    }
    
    @Test("Unknown iPads return formatted fallback")
    func testUnknownIPad() {
        let name = DeviceNames.friendlyName(for: "iPad99,9")
        #expect(name == "iPad (iPad99,9)")
    }
    
    @Test("Completely unknown returns identifier")
    func testUnknownDevice() {
        let name = DeviceNames.friendlyName(for: "SomeDevice123")
        #expect(name == "SomeDevice123")
    }
    
    @Test("isDuo correctly identifies Duo models")
    func testIsDuo() {
        #expect(DeviceNames.isDuo(modelIdentifier: "iPhone19,4"))
        #expect(!DeviceNames.isDuo(modelIdentifier: "iPhone19,2"))
        #expect(!DeviceNames.isDuo(modelIdentifier: "iPhone19,3"))
        #expect(!DeviceNames.isDuo(modelIdentifier: "iPhone18,1"))
        #expect(!DeviceNames.isDuo(modelIdentifier: "iPhone17,1"))
    }
}
