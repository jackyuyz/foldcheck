import Testing
import Foundation
@testable import TestsKit

@Suite("TestID Tests")
struct TestIDTests {
    
    @Test("All test IDs have display names")
    func testDisplayNames() {
        for testID in TestID.allCases {
            #expect(!testID.displayName.isEmpty)
        }
    }
    
    @Test("All test IDs have descriptions")
    func testDescriptions() {
        for testID in TestID.allCases {
            #expect(!testID.testDescription.isEmpty)
        }
    }
    
    @Test("Hinge-requiring tests are correctly identified")
    func testHingeRequirement() {
        let hingeTests: Set<TestID> = [.touchGridInner, .crease, .hingeSweep]
        
        for testID in TestID.allCases {
            if hingeTests.contains(testID) {
                #expect(testID.requiresHinge, "\(testID) should require hinge")
            } else {
                #expect(!testID.requiresHinge, "\(testID) should not require hinge")
            }
        }
    }
    
    @Test("Estimated durations are reasonable")
    func testEstimatedDurations() {
        for testID in TestID.allCases {
            #expect(testID.estimatedDurationSeconds > 0)
            #expect(testID.estimatedDurationSeconds <= 120)  // No test should take > 2 minutes
        }
    }
    
    @Test("Default order contains all tests")
    func testDefaultOrder() {
        let orderedSet = Set(TestID.defaultOrder)
        let allSet = Set(TestID.allCases)
        #expect(orderedSet == allSet)
    }
    
    @Test("TestID is Codable")
    func testCodable() throws {
        let encoder = JSONEncoder()
        let decoder = JSONDecoder()
        
        for testID in TestID.allCases {
            let data = try encoder.encode(testID)
            let decoded = try decoder.decode(TestID.self, from: data)
            #expect(decoded == testID)
        }
    }
    
    @Test("TestID raw values are stable")
    func testRawValues() {
        #expect(TestID.touchGridOuter.rawValue == "touchGridOuter")
        #expect(TestID.touchGridInner.rawValue == "touchGridInner")
        #expect(TestID.pixels.rawValue == "pixels")
        #expect(TestID.crease.rawValue == "crease")
        #expect(TestID.hingeSweep.rawValue == "hingeSweep")
        #expect(TestID.cameras.rawValue == "cameras")
        #expect(TestID.audio.rawValue == "audio")
        #expect(TestID.touchID.rawValue == "touchID")
        #expect(TestID.sensors.rawValue == "sensors")
        #expect(TestID.buttons.rawValue == "buttons")
    }
}
