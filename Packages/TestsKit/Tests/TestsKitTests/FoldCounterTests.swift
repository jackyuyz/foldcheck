import Testing
import Foundation
@testable import TestsKit
import FoldKit

@Suite("FoldCounter Tests")
struct FoldCounterTests {
    let t0 = Date(timeIntervalSinceReferenceDate: 1_000_000)

    func at(_ seconds: TimeInterval) -> Date {
        t0.addingTimeInterval(seconds)
    }

    func state(_ posture: FoldPosture) -> FoldState {
        FoldState(posture: posture, angleDegrees: posture == .closed ? 0 : (posture == .fullyOpen ? 180 : 90))
    }

    /// A tracking counter that starts closed at t=0.
    func trackingClosed() -> FoldCounter {
        var counter = FoldCounter(stats: .init(startedAt: t0, updatedAt: t0))
        counter.startTracking(at: t0)
        counter.process(state(.closed), at: t0)
        return counter
    }

    @Test("Counter starts with zero counts")
    func testInitialState() {
        let stats = FoldCounter().stats(at: t0)
        #expect(stats.foldCount == 0)
        #expect(stats.closedDuration == 0)
        #expect(stats.openDuration == 0)
        #expect(stats.partialDuration == 0)
    }

    @Test("Counter only tracks after startTracking (foreground only)")
    func testStartTracking() {
        var counter = FoldCounter()
        counter.process(state(.closed), at: at(0))
        counter.process(state(.fullyOpen), at: at(1))
        #expect(counter.stats(at: at(5)).foldCount == 0)
        #expect(counter.stats(at: at(5)).totalDuration == 0)

        counter.startTracking(at: at(10))
        counter.process(state(.closed), at: at(10))
        counter.process(state(.fullyOpen), at: at(11))
        #expect(counter.stats(at: at(12)).foldCount == 1)
    }

    @Test("Closed→open counts once the open posture has lasted the debounce")
    func testFoldCounting() {
        var counter = trackingClosed()
        counter.process(state(.fullyOpen), at: at(1))
        #expect(counter.stats(at: at(1.1)).foldCount == 0)  // still debouncing
        #expect(counter.stats(at: at(1.3)).foldCount == 1)

        // open → closed → partially open = another fold
        counter.process(state(.closed), at: at(3))
        counter.process(state(.partiallyOpen), at: at(5))
        #expect(counter.stats(at: at(6)).foldCount == 2)
    }

    @Test("Flapping across the boundary inside the debounce is not a fold")
    func testDebounce() {
        var counter = trackingClosed()
        counter.process(state(.partiallyOpen), at: at(1.0))
        counter.process(state(.closed), at: at(1.1))
        counter.process(state(.partiallyOpen), at: at(1.15))
        counter.process(state(.closed), at: at(1.2))
        #expect(counter.stats(at: at(3)).foldCount == 0)
        // A brief closed blip while open doesn't make the next opening a new fold either.
        counter.process(state(.fullyOpen), at: at(4))
        counter.process(state(.closed), at: at(5))
        counter.process(state(.fullyOpen), at: at(5.1))
        #expect(counter.stats(at: at(8)).foldCount == 1)
    }

    @Test("Partially open then fully open while debouncing is one fold")
    func testSameSideDuringDebounce() {
        var counter = trackingClosed()
        counter.process(state(.partiallyOpen), at: at(1))
        counter.process(state(.fullyOpen), at: at(1.1))
        #expect(counter.stats(at: at(2)).foldCount == 1)
    }

    @Test("Unknown and no-hinge readings are ignored")
    func testIgnoredPostures() {
        var counter = trackingClosed()
        counter.process(state(.unknown), at: at(1))
        counter.process(FoldState.noHinge, at: at(2))
        #expect(counter.stats(at: at(4)).foldCount == 0)
        #expect(counter.stats(at: at(4)).closedDuration == 4)
    }

    @Test("Open→Closed does not count as a fold")
    func testOpenToClosedNotCounted() {
        var counter = FoldCounter()
        counter.startTracking(at: at(0))
        counter.process(state(.fullyOpen), at: at(0))
        counter.process(state(.closed), at: at(1))
        #expect(counter.stats(at: at(3)).foldCount == 0)
    }

    @Test("PartiallyOpen→FullyOpen does not count as a fold")
    func testPartialToOpenNotCounted() {
        var counter = FoldCounter()
        counter.startTracking(at: at(0))
        counter.process(state(.partiallyOpen), at: at(0))
        counter.process(state(.fullyOpen), at: at(1))
        #expect(counter.stats(at: at(3)).foldCount == 0)
    }

    @Test("Folds while backgrounded are not counted (AC7)")
    func testBackgroundNotCounted() {
        var counter = trackingClosed()
        counter.stopTracking(at: at(1))
        // Opened while in the background; FoldCheck didn't see it happen.
        counter.process(state(.fullyOpen), at: at(2))
        counter.startTracking(at: at(10))
        counter.process(state(.fullyOpen), at: at(10))
        #expect(counter.stats(at: at(12)).foldCount == 0)
        // The background gap adds no time either.
        #expect(counter.stats(at: at(12)).closedDuration == 1)
        #expect(counter.stats(at: at(12)).openDuration == 2)
        // A fold observed in the foreground after returning does count.
        counter.process(state(.closed), at: at(13))
        counter.process(state(.fullyOpen), at: at(14))
        #expect(counter.stats(at: at(15)).foldCount == 1)
    }

    @Test("A pending change is dropped when tracking stops")
    func testPendingDroppedOnStop() {
        var counter = trackingClosed()
        counter.process(state(.fullyOpen), at: at(1))
        counter.stopTracking(at: at(1.1))
        #expect(counter.stats(at: at(5)).foldCount == 0)
    }

    @Test("Time per display follows the accepted posture")
    func testDurations() {
        var counter = trackingClosed()
        counter.process(state(.partiallyOpen), at: at(10))
        counter.process(state(.fullyOpen), at: at(20))
        let stats = counter.stats(at: at(40))
        #expect(stats.closedDuration == 10)
        #expect(stats.partialDuration == 10)
        #expect(stats.openDuration == 20)
        #expect(stats.closedPercent == 25)
        #expect(stats.innerPercent == 75)
    }

    @Test("Continuing from persisted totals adds to them")
    func testContinueFromTotals() {
        let saved = FoldCounter.Stats(foldCount: 41, closedDuration: 100, startedAt: t0, updatedAt: t0)
        var counter = FoldCounter(stats: saved)
        counter.startTracking(at: at(0))
        counter.process(state(.closed), at: at(0))
        counter.process(state(.fullyOpen), at: at(5))
        let stats = counter.stats(at: at(6))
        #expect(stats.foldCount == 42)
        #expect(stats.closedDuration == 105)
        #expect(stats.startedAt == t0)
    }

    @Test("Reset clears all statistics")
    func testReset() {
        var counter = trackingClosed()
        counter.process(state(.fullyOpen), at: at(1))
        #expect(counter.stats(at: at(2)).foldCount == 1)
        counter.reset(at: at(3))
        let stats = counter.stats(at: at(3))
        #expect(stats.foldCount == 0)
        #expect(stats.totalDuration == 0)
        #expect(stats.startedAt == at(3))
        #expect(counter.stats(at: at(5)).openDuration == 2)
    }

    @Test("Stats calculate percentages correctly")
    func testStatsPercentages() {
        let stats = FoldCounter.Stats(foldCount: 5, closedDuration: 30, openDuration: 60, partialDuration: 10)
        #expect(stats.totalDuration == 100)
        #expect(stats.closedPercent == 30)
        #expect(stats.innerPercent == 70)
    }

    @Test("Stats handle zero total duration")
    func testStatsZeroDuration() {
        let stats = FoldCounter.Stats()
        #expect(stats.closedPercent == 0)
        #expect(stats.innerPercent == 0)
    }

    @Test("FoldCounter.Stats is Codable")
    func testStatsCodable() throws {
        let original = FoldCounter.Stats(foldCount: 10, closedDuration: 100, openDuration: 200, partialDuration: 50, startedAt: t0, updatedAt: at(5))
        let decoded = try JSONDecoder().decode(FoldCounter.Stats.self, from: JSONEncoder().encode(original))
        #expect(decoded == original)
    }
}
