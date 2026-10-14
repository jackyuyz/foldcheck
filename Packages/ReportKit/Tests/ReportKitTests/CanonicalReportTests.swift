import Testing
import Foundation
@testable import ReportKit
import TestsKit

@Suite("CanonicalReport Tests")
struct CanonicalReportTests {
    
    @Test("CanonicalReport initializes correctly")
    func testInitialization() {
        let report = CanonicalReport(
            deviceModel: "iPhone 19 Duo",
            osVersion: "iOS 27.0",
            hasHinge: true,
            inspectionStartedAt: Date(),
            results: []
        )
        
        #expect(report.deviceModel == "iPhone 19 Duo")
        #expect(report.osVersion == "iOS 27.0")
        #expect(report.hasHinge)
        #expect(report.reportVersion == 1)
    }
    
    @Test("CanonicalReport creates from InspectionSession")
    func testFromSession() {
        var session = InspectionSession(
            deviceModel: "iPhone 19 Duo",
            osVersion: "iOS 27.0",
            storageCapacity: 256_000_000_000,
            hasHinge: true
        )
        session.setResult(TestResult(id: .touchGridOuter, outcome: .pass))
        session.setResult(TestResult(id: .hingeSweep, outcome: .attention, metrics: ["maxGap": 15.5]))
        
        let report = CanonicalReport.from(session: session, appVersion: "1.0.0")
        
        #expect(report.deviceModel == session.deviceModel)
        #expect(report.osVersion == session.osVersion)
        #expect(report.hasHinge == session.hasHinge)
        #expect(report.results.count == 2)
        #expect(report.appVersion == "1.0.0")
    }
    
    @Test("Canonical JSON is deterministic")
    func testDeterministicJSON() throws {
        let report = CanonicalReport(
            reportID: UUID(uuidString: "12345678-1234-1234-1234-123456789012")!,
            generatedAt: Date(timeIntervalSince1970: 1000000),
            deviceModel: "iPhone 19 Duo",
            osVersion: "iOS 27.0",
            hasHinge: true,
            inspectionStartedAt: Date(timeIntervalSince1970: 999000),
            results: [
                CanonicalTestResult(
                    testID: "touchGridOuter",
                    outcome: "pass",
                    metrics: ["coverage": 100.0],
                    notes: "",
                    display: nil,
                    finishedAt: Date(timeIntervalSince1970: 999500)
                )
            ]
        )
        
        let json1 = try report.toCanonicalJSON()
        let json2 = try report.toCanonicalJSON()
        
        #expect(json1 == json2)
    }
    
    @Test("Canonical JSON round-trips correctly")
    func testJSONRoundTrip() throws {
        let original = CanonicalReport(
            reportID: UUID(),
            generatedAt: Date(),
            deviceModel: "iPhone 19 Duo",
            osVersion: "iOS 27.0",
            storageCapacityBytes: 256_000_000_000,
            hasHinge: true,
            inspectionStartedAt: Date(),
            inspectionCompletedAt: Date(),
            results: [
                CanonicalTestResult(
                    testID: "hingeSweep",
                    outcome: "attention",
                    metrics: ["maxGap": 15.5, "continuity": 0.95],
                    notes: "Some notes",
                    display: "inner",
                    finishedAt: Date()
                )
            ]
        )
        
        let json = try original.toCanonicalJSON()
        let decoded = try CanonicalReport.fromJSON(json)
        
        #expect(decoded.reportID == original.reportID)
        #expect(decoded.deviceModel == original.deviceModel)
        #expect(decoded.results.count == original.results.count)
        #expect(decoded.results[0].testID == original.results[0].testID)
        #expect(decoded.results[0].metrics["maxGap"] == original.results[0].metrics["maxGap"])
    }
}

@Suite("CanonicalTestResult Tests")
struct CanonicalTestResultTests {
    
    @Test("CanonicalTestResult creates from TestResult")
    func testFromTestResult() {
        let result = TestResult(
            id: .hingeSweep,
            outcome: .attention,
            metrics: ["maxGap": 15.5],
            notes: "Test notes",
            display: .inner,
            finishedAt: Date()
        )
        
        let canonical = CanonicalTestResult.from(result)
        
        #expect(canonical.testID == "hingeSweep")
        #expect(canonical.outcome == "attention")
        #expect(canonical.metrics["maxGap"] == 15.5)
        #expect(canonical.notes == "Test notes")
        #expect(canonical.display == "inner")
    }
}
