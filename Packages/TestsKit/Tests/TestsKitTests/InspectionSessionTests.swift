import Testing
import Foundation
@testable import TestsKit

@Suite("InspectionSession Tests")
struct InspectionSessionTests {
    
    @Test("Session initializes with correct default values")
    func testInitialization() {
        let session = InspectionSession(
            deviceModel: "iPhone 19 Duo",
            osVersion: "iOS 27.0",
            hasHinge: true
        )
        
        #expect(session.deviceModel == "iPhone 19 Duo")
        #expect(session.osVersion == "iOS 27.0")
        #expect(session.hasHinge)
        #expect(session.results.isEmpty)
        #expect(session.reportFile == nil)
        #expect(session.signatureB64 == nil)
        #expect(session.completedAt == nil)
    }
    
    @Test("setResult adds new results")
    func testSetResultNew() {
        var session = InspectionSession(deviceModel: "Test", osVersion: "1.0", hasHinge: true)
        
        let result = TestResult(id: .touchGridOuter, outcome: .pass)
        session.setResult(result)
        
        #expect(session.results.count == 1)
        #expect(session.result(for: .touchGridOuter)?.outcome == .pass)
    }
    
    @Test("setResult updates existing results")
    func testSetResultUpdate() {
        var session = InspectionSession(deviceModel: "Test", osVersion: "1.0", hasHinge: true)
        
        session.setResult(TestResult(id: .touchGridOuter, outcome: .pass))
        session.setResult(TestResult(id: .touchGridOuter, outcome: .fail))
        
        #expect(session.results.count == 1)
        #expect(session.result(for: .touchGridOuter)?.outcome == .fail)
    }
    
    @Test("isCompleted returns correct values")
    func testIsCompleted() {
        var session = InspectionSession(deviceModel: "Test", osVersion: "1.0", hasHinge: true)
        
        #expect(!session.isCompleted(.touchGridOuter))
        
        session.setResult(TestResult(id: .touchGridOuter, outcome: .pass))
        
        #expect(session.isCompleted(.touchGridOuter))
        #expect(!session.isCompleted(.pixels))
    }
    
    @Test("Outcome counts are calculated correctly")
    func testOutcomeCounts() {
        var session = InspectionSession(deviceModel: "Test", osVersion: "1.0", hasHinge: true)
        
        session.setResult(TestResult(id: .touchGridOuter, outcome: .pass))
        session.setResult(TestResult(id: .touchGridInner, outcome: .pass))
        session.setResult(TestResult(id: .pixels, outcome: .attention))
        session.setResult(TestResult(id: .cameras, outcome: .fail))
        session.setResult(TestResult(id: .audio, outcome: .skipped))
        
        #expect(session.passCount == 2)
        #expect(session.attentionCount == 1)
        #expect(session.failCount == 1)
        #expect(session.completedCount == 4)  // pass, attention, fail count as completed
    }
    
    @Test("Overall score is calculated correctly")
    func testOverallScore() {
        var session = InspectionSession(deviceModel: "Test", osVersion: "1.0", hasHinge: true)
        
        session.setResult(TestResult(id: .touchGridOuter, outcome: .pass))   // 100
        session.setResult(TestResult(id: .pixels, outcome: .attention))       // 70
        session.setResult(TestResult(id: .cameras, outcome: .fail))           // 0
        
        // Average: (100 + 70 + 0) / 3 = 56.67 → 56
        #expect(session.overallScore == 56)
    }
    
    @Test("Overall score ignores skipped and N/A tests")
    func testOverallScoreIgnoresNonScorable() {
        var session = InspectionSession(deviceModel: "Test", osVersion: "1.0", hasHinge: false)
        
        session.setResult(TestResult(id: .touchGridOuter, outcome: .pass))
        session.setResult(TestResult(id: .hingeSweep, outcome: .notApplicable))
        session.setResult(TestResult(id: .audio, outcome: .skipped))
        
        // Only .pass (100) is scored
        #expect(session.overallScore == 100)
    }
    
    @Test("Overall score returns nil for empty results")
    func testOverallScoreEmpty() {
        let session = InspectionSession(deviceModel: "Test", osVersion: "1.0", hasHinge: true)
        #expect(session.overallScore == nil)
    }
    
    @Test("Overall status reflects worst outcome")
    func testOverallStatus() {
        var session = InspectionSession(deviceModel: "Test", osVersion: "1.0", hasHinge: true)
        
        #expect(session.overallStatus == .skipped)  // Empty
        
        session.setResult(TestResult(id: .touchGridOuter, outcome: .pass))
        #expect(session.overallStatus == .pass)
        
        session.setResult(TestResult(id: .pixels, outcome: .attention))
        #expect(session.overallStatus == .attention)
        
        session.setResult(TestResult(id: .cameras, outcome: .fail))
        #expect(session.overallStatus == .fail)
    }
    
    @Test("Duration is calculated correctly")
    func testDuration() {
        let startedAt = Date()
        let completedAt = startedAt.addingTimeInterval(300)  // 5 minutes
        
        var session = InspectionSession(deviceModel: "Test", osVersion: "1.0", hasHinge: true)
        session.startedAt = startedAt
        session.completedAt = completedAt
        
        #expect(session.durationSeconds == 300)
        #expect(session.durationString == "5m 0s")
    }
    
    @Test("Duration string formats correctly")
    func testDurationString() {
        var session = InspectionSession(deviceModel: "Test", osVersion: "1.0", hasHinge: true)
        
        session.startedAt = Date()
        session.completedAt = session.startedAt.addingTimeInterval(45)
        #expect(session.durationString == "45s")
        
        session.completedAt = session.startedAt.addingTimeInterval(125)
        #expect(session.durationString == "2m 5s")
    }
    
    @Test("InspectionSession is Codable")
    func testCodable() throws {
        let encoder = JSONEncoder()
        let decoder = JSONDecoder()
        
        var session = InspectionSession(
            deviceModel: "iPhone 19 Duo",
            osVersion: "iOS 27.0",
            storageCapacity: 256_000_000_000,
            hasHinge: true
        )
        session.setResult(TestResult(id: .touchGridOuter, outcome: .pass))
        session.setResult(TestResult(id: .hingeSweep, outcome: .attention, metrics: ["maxGap": 15.5]))
        session.completedAt = Date()
        
        let data = try encoder.encode(session)
        let decoded = try decoder.decode(InspectionSession.self, from: data)
        
        #expect(decoded.deviceModel == session.deviceModel)
        #expect(decoded.osVersion == session.osVersion)
        #expect(decoded.hasHinge == session.hasHinge)
        #expect(decoded.results.count == session.results.count)
        #expect(decoded.storageCapacity == session.storageCapacity)
    }
    
    @Test("Storage capacity formats correctly")
    func testStorageFormatting() {
        let session = InspectionSession(
            deviceModel: "Test",
            osVersion: "1.0",
            storageCapacity: 256_000_000_000,
            hasHinge: true
        )
        
        let formatted = session.storageCapacityFormatted
        #expect(formatted != nil)
        #expect(formatted!.contains("GB") || formatted!.contains("bytes"))
    }
}
