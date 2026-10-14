import Testing
import Foundation
@testable import TestsKit

@Suite("TestOutcome Tests")
struct TestOutcomeTests {
    
    @Test("All outcomes have display names")
    func testDisplayNames() {
        for outcome in [TestOutcome.pass, .attention, .fail, .skipped, .notApplicable] {
            #expect(!outcome.displayName.isEmpty)
        }
    }
    
    @Test("Completed outcomes are correctly identified")
    func testIsCompleted() {
        #expect(TestOutcome.pass.isCompleted)
        #expect(TestOutcome.attention.isCompleted)
        #expect(TestOutcome.fail.isCompleted)
        #expect(!TestOutcome.skipped.isCompleted)
        #expect(!TestOutcome.notApplicable.isCompleted)
    }
    
    @Test("All outcomes have color names")
    func testColorNames() {
        #expect(TestOutcome.pass.colorName == "green")
        #expect(TestOutcome.attention.colorName == "amber")
        #expect(TestOutcome.fail.colorName == "red")
        #expect(TestOutcome.skipped.colorName == "gray")
        #expect(TestOutcome.notApplicable.colorName == "gray")
    }
    
    @Test("All outcomes have icon names")
    func testIconNames() {
        for outcome in [TestOutcome.pass, .attention, .fail, .skipped, .notApplicable] {
            #expect(!outcome.iconName.isEmpty)
        }
    }
    
    @Test("Scores are correct")
    func testScores() {
        #expect(TestOutcome.pass.score == 100)
        #expect(TestOutcome.attention.score == 70)
        #expect(TestOutcome.fail.score == 0)
        #expect(TestOutcome.skipped.score == -1)
        #expect(TestOutcome.notApplicable.score == -1)
    }
    
    @Test("TestOutcome is Codable")
    func testCodable() throws {
        let encoder = JSONEncoder()
        let decoder = JSONDecoder()
        
        for outcome in [TestOutcome.pass, .attention, .fail, .skipped, .notApplicable] {
            let data = try encoder.encode(outcome)
            let decoded = try decoder.decode(TestOutcome.self, from: data)
            #expect(decoded == outcome)
        }
    }
    
    @Test("TestOutcome raw values are stable")
    func testRawValues() {
        #expect(TestOutcome.pass.rawValue == "pass")
        #expect(TestOutcome.attention.rawValue == "attention")
        #expect(TestOutcome.fail.rawValue == "fail")
        #expect(TestOutcome.skipped.rawValue == "skipped")
        #expect(TestOutcome.notApplicable.rawValue == "notApplicable")
    }
}
