import Testing
import Foundation
@testable import TestsKit
import FoldKit

@Suite("FoldCounter Tests")
struct FoldCounterTests {
    
    @Test("Counter starts with zero counts")
    func testInitialState() async {
        let counter = FoldCounter()
        let stats = await counter.getStats()
        
        #expect(stats.foldCount == 0)
        #expect(stats.closedDuration == 0)
        #expect(stats.openDuration == 0)
        #expect(stats.partialDuration == 0)
    }
    
    @Test("Counter only tracks after startTracking")
    func testStartTracking() async {
        let counter = FoldCounter()
        
        // Process before tracking - should not count
        await counter.process(FoldState(posture: .closed, angleDegrees: 0))
        await counter.process(FoldState(posture: .fullyOpen, angleDegrees: 180))
        
        var stats = await counter.getStats()
        #expect(stats.foldCount == 0)
        
        // Start tracking and then process
        await counter.startTracking()
        await counter.process(FoldState(posture: .closed, angleDegrees: 0))
        await counter.process(FoldState(posture: .fullyOpen, angleDegrees: 180))
        
        stats = await counter.getStats()
        #expect(stats.foldCount == 1)  // closed → open transition
    }
    
    @Test("Closed→Open transition counts as a fold")
    func testFoldCounting() async {
        let counter = FoldCounter()
        await counter.startTracking()
        
        // closed → open = 1 fold
        await counter.process(FoldState(posture: .closed, angleDegrees: 0))
        await counter.process(FoldState(posture: .fullyOpen, angleDegrees: 180))
        
        var stats = await counter.getStats()
        #expect(stats.foldCount == 1)
        
        // open → closed → open = another fold
        await counter.process(FoldState(posture: .closed, angleDegrees: 0))
        await counter.process(FoldState(posture: .partiallyOpen, angleDegrees: 90))
        
        stats = await counter.getStats()
        #expect(stats.foldCount == 2)  // closed → partiallyOpen also counts
    }
    
    @Test("Open→Closed does not count as a fold")
    func testOpenToClosedNotCounted() async {
        let counter = FoldCounter()
        await counter.startTracking()
        
        // Start open, go to closed - not a fold
        await counter.process(FoldState(posture: .fullyOpen, angleDegrees: 180))
        await counter.process(FoldState(posture: .closed, angleDegrees: 0))
        
        let stats = await counter.getStats()
        #expect(stats.foldCount == 0)
    }
    
    @Test("PartiallyOpen→FullyOpen does not count as a fold")
    func testPartialToOpenNotCounted() async {
        let counter = FoldCounter()
        await counter.startTracking()
        
        await counter.process(FoldState(posture: .partiallyOpen, angleDegrees: 90))
        await counter.process(FoldState(posture: .fullyOpen, angleDegrees: 180))
        
        let stats = await counter.getStats()
        #expect(stats.foldCount == 0)
    }
    
    @Test("Reset clears all statistics")
    func testReset() async {
        let counter = FoldCounter()
        await counter.startTracking()
        
        await counter.process(FoldState(posture: .closed, angleDegrees: 0))
        await counter.process(FoldState(posture: .fullyOpen, angleDegrees: 180))
        
        await counter.reset()
        
        let stats = await counter.getStats()
        #expect(stats.foldCount == 0)
        #expect(stats.closedDuration == 0)
        #expect(stats.openDuration == 0)
    }
    
    @Test("Stats calculate percentages correctly")
    func testPercentages() {
        let stats = FoldCounter.Stats(
            foldCount: 5,
            closedDuration: 30,
            openDuration: 60,
            partialDuration: 10
        )
        
        #expect(stats.totalDuration == 100)
        #expect(stats.closedPercent == 30)  // 30/100 * 100
        #expect(stats.innerPercent == 70)   // (60+10)/100 * 100
    }
    
    @Test("Stats handle zero total duration")
    func testZeroDuration() {
        let stats = FoldCounter.Stats()
        
        #expect(stats.totalDuration == 0)
        #expect(stats.closedPercent == 0)
        #expect(stats.innerPercent == 0)
    }
    
    @Test("FoldCounter.Stats is Codable")
    func testStatsCodable() throws {
        let encoder = JSONEncoder()
        let decoder = JSONDecoder()
        
        let original = FoldCounter.Stats(
            foldCount: 10,
            closedDuration: 100,
            openDuration: 200,
            partialDuration: 50
        )
        
        let data = try encoder.encode(original)
        let decoded = try decoder.decode(FoldCounter.Stats.self, from: data)
        
        #expect(decoded == original)
    }
}
