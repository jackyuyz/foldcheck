import Testing
import Foundation
@testable import HingeAnalysis
import FoldKit

@Suite("HingeSweepAnalyzer Tests")
struct HingeSweepAnalyzerTests {
    let analyzer = HingeSweepAnalyzer()
    
    // MARK: - Clean Sweep Tests
    
    @Test("Clean sweep produces Pass quality")
    func testCleanSweep() {
        // Generate a clean monotonic sweep from 0 to 180 over 6 seconds at 30 Hz
        var collection = HingeSampleCollection()
        let sampleCount = 180
        
        for i in 0..<sampleCount {
            let t = Double(i) / 30.0
            let degrees = Double(i)
            let status: FoldPosture
            if degrees < 10 {
                status = .closed
            } else if degrees > 170 {
                status = .fullyOpen
            } else {
                status = .partiallyOpen
            }
            collection.append(HingeSample(degrees: degrees, status: status, t: t))
        }
        
        let report = analyzer.analyze(collection)
        
        #expect(report.observedMin == 0)
        #expect(report.observedMax == 179)  // 0 to 179
        #expect(report.monotonicFraction == 1.0)
        #expect(report.maxGapDegrees == 1.0)
        #expect(report.assessQuality() == .pass)
    }
    
    @Test("Clean reverse sweep produces Pass quality")
    func testCleanReverseSweep() {
        var collection = HingeSampleCollection()
        let sampleCount = 180
        
        for i in 0..<sampleCount {
            let t = Double(i) / 30.0
            let degrees = 180.0 - Double(i)
            let status: FoldPosture
            if degrees < 10 {
                status = .closed
            } else if degrees > 170 {
                status = .fullyOpen
            } else {
                status = .partiallyOpen
            }
            collection.append(HingeSample(degrees: degrees, status: status, t: t))
        }
        
        let report = analyzer.analyze(collection)
        
        #expect(report.observedMin == 1)  // 180 down to 1
        #expect(report.observedMax == 180)
        #expect(report.monotonicFraction == 1.0)
        #expect(report.assessQuality() == .pass)
    }
    
    // MARK: - Gappy Sweep Tests
    
    @Test("Sweep with 25° gap produces Attention, not Fail")
    func testGappySweepAttentionAt25() {
        var collection = HingeSampleCollection()
        
        // 0 to 90, then jump to 115 (25° gap), then to 180
        for i in 0...90 {
            collection.append(HingeSample(degrees: Double(i), status: .partiallyOpen, t: Double(i) / 30.0))
        }
        collection.append(HingeSample(degrees: 115, status: .partiallyOpen, t: 91.0 / 30.0))
        for i in 116...180 {
            collection.append(HingeSample(degrees: Double(i), status: .partiallyOpen, t: Double(i - 24) / 30.0))
        }
        
        let report = analyzer.analyze(collection)
        
        #expect(report.maxGapDegrees >= 25.0)
        #expect(report.assessQuality() == .attention)
        #expect(report.assessQuality() != .fail)
    }
    
    @Test("Sweep with 15° gap produces Attention quality")
    func testGappySweepAttention() {
        var collection = HingeSampleCollection()
        
        // 0 to 90, then jump to 105 (15° gap), then to 180
        for i in 0...90 {
            collection.append(HingeSample(degrees: Double(i), status: .partiallyOpen, t: Double(i) / 30.0))
        }
        collection.append(HingeSample(degrees: 105, status: .partiallyOpen, t: 91.0 / 30.0))
        for i in 106...180 {
            collection.append(HingeSample(degrees: Double(i), status: .fullyOpen, t: Double(i - 14) / 30.0))
        }
        
        let report = analyzer.analyze(collection)
        
        #expect(report.maxGapDegrees >= 14.0)
        #expect(report.maxGapDegrees < 25.0)
        #expect(report.assessQuality() == .attention)
    }
    
    // MARK: - Non-Monotonic Sweep Tests
    
    @Test("Jittery sweep with direction changes produces Attention")
    func testJitterySweep() {
        var collection = HingeSampleCollection()
        
        // Sweep with frequent direction reversals
        var angle = 0.0
        for i in 0..<180 {
            // Add jitter: +1 then -0.5 alternating
            if i % 2 == 0 {
                angle += 2
            } else {
                angle -= 0.5
            }
            let status: FoldPosture
            if angle < 10 {
                status = .closed
            } else if angle > 170 {
                status = .fullyOpen
            } else {
                status = .partiallyOpen
            }
            collection.append(HingeSample(degrees: angle, status: status, t: Double(i) / 30.0))
        }
        
        let report = analyzer.analyze(collection)
        
        // Should have lower monotonic fraction due to reversals
        #expect(report.monotonicFraction < 1.0)
        #expect(report.monotonicFraction > 0.5)  // Still mostly monotonic
    }
    
    @Test("Highly non-monotonic sweep produces Attention")
    func testHighlyNonMonotonicSweep() {
        var collection = HingeSampleCollection()
        
        // Oscillating pattern - definitely not monotonic
        for i in 0..<60 {
            let angle = 90 + 30 * sin(Double(i) * 0.5)  // Oscillate around 90°
            collection.append(HingeSample(degrees: angle, status: .partiallyOpen, t: Double(i) / 30.0))
        }
        
        let report = analyzer.analyze(collection)
        
        // Highly oscillating should have low monotonic fraction
        #expect(report.monotonicFraction < 0.7)
        #expect(report.assessQuality() == .attention)
    }
    
    // MARK: - Insufficient Data Tests
    
    @Test("Empty collection produces Unavailable quality")
    func testEmptyCollection() {
        let collection = HingeSampleCollection()
        let report = analyzer.analyze(collection)
        
        #expect(report.sampleCount == 0)
        #expect(report.assessQuality() == .unavailable)
    }
    
    @Test("Few samples produces Unavailable quality")
    func testFewSamples() {
        var collection = HingeSampleCollection()
        for i in 0..<5 {
            collection.append(HingeSample(degrees: Double(i * 10), status: .partiallyOpen, t: Double(i) / 30.0))
        }
        
        let report = analyzer.analyze(collection)
        
        #expect(report.sampleCount < 10)
        #expect(report.assessQuality() == .unavailable)
    }
    
    // MARK: - Status Sequence Tests
    
    @Test("Status sequence is extracted correctly")
    func testStatusSequence() {
        var collection = HingeSampleCollection()
        
        // closed -> partiallyOpen -> fullyOpen
        collection.append(HingeSample(degrees: 0, status: .closed, t: 0))
        collection.append(HingeSample(degrees: 5, status: .closed, t: 0.1))
        collection.append(HingeSample(degrees: 20, status: .partiallyOpen, t: 0.2))
        collection.append(HingeSample(degrees: 90, status: .partiallyOpen, t: 0.5))
        collection.append(HingeSample(degrees: 170, status: .partiallyOpen, t: 0.8))
        collection.append(HingeSample(degrees: 175, status: .fullyOpen, t: 0.9))
        collection.append(HingeSample(degrees: 180, status: .fullyOpen, t: 1.0))
        
        let report = analyzer.analyze(collection)
        
        #expect(report.statusSequence == [.closed, .partiallyOpen, .fullyOpen])
        #expect(report.hasExpectedTransitions == true)
    }
    
    @Test("Missing transitions are detected")
    func testMissingTransitions() {
        var collection = HingeSampleCollection()
        
        // Only partiallyOpen status despite wide angle range
        for i in 0..<100 {
            collection.append(HingeSample(degrees: Double(i) * 1.8, status: .partiallyOpen, t: Double(i) / 30.0))
        }
        
        let report = analyzer.analyze(collection)
        
        #expect(report.statusSequence == [.partiallyOpen])
        #expect(report.hasExpectedTransitions == false)
    }
    
    // MARK: - Partial Range Tests
    
    @Test("Partial range sweep (30°-170°) is not a failure")
    func testPartialRangeSweep() {
        var collection = HingeSampleCollection()
        
        // User only sweeps from 30° to 170° (not full range)
        for i in 30...170 {
            let status: FoldPosture
            if i < 40 {
                status = .partiallyOpen
            } else if i > 160 {
                status = .fullyOpen
            } else {
                status = .partiallyOpen
            }
            collection.append(HingeSample(degrees: Double(i), status: status, t: Double(i - 30) / 30.0))
        }
        
        let report = analyzer.analyze(collection)
        
        #expect(report.observedMin == 30)
        #expect(report.observedMax == 170)
        #expect(report.observedRange == 140)
        // Partial range with good data should still pass
        #expect(report.assessQuality() == .pass)
    }
}

@Suite("HingeSweepReport Tests")
struct HingeSweepReportTests {
    
    @Test("HingeSweepReport is Codable")
    func testCodable() throws {
        let encoder = JSONEncoder()
        let decoder = JSONDecoder()
        
        let original = HingeSweepReport(
            observedMin: 5,
            observedMax: 175,
            maxGapDegrees: 3.5,
            restJitterDegrees: 0.5,
            estimatedHz: 30,
            monotonicFraction: 0.95,
            statusSequence: [.closed, .partiallyOpen, .fullyOpen],
            sampleCount: 180,
            durationSeconds: 6.0
        )
        
        let data = try encoder.encode(original)
        let decoded = try decoder.decode(HingeSweepReport.self, from: data)
        
        #expect(decoded == original)
    }
    
    @Test("observedRange calculated correctly")
    func testObservedRange() {
        let report = HingeSweepReport(
            observedMin: 10,
            observedMax: 170,
            maxGapDegrees: 1,
            restJitterDegrees: 0.5,
            estimatedHz: 30,
            monotonicFraction: 1.0,
            statusSequence: [.closed, .partiallyOpen, .fullyOpen]
        )
        
        #expect(report.observedRange == 160)
    }
    
    @Test("qualityDescription provides appropriate text for each quality")
    func testQualityDescription() {
        let passReport = HingeSweepReport(
            observedMin: 0, observedMax: 180, maxGapDegrees: 1,
            restJitterDegrees: 0.5, estimatedHz: 30, monotonicFraction: 1.0,
            statusSequence: [.closed, .partiallyOpen, .fullyOpen], sampleCount: 100
        )
        #expect(passReport.qualityDescription.contains("smoothly"))
        
        let gapReport = HingeSweepReport(
            observedMin: 0, observedMax: 180, maxGapDegrees: 20,
            restJitterDegrees: 0.5, estimatedHz: 30, monotonicFraction: 1.0,
            statusSequence: [.closed, .partiallyOpen, .fullyOpen], sampleCount: 100
        )
        #expect(gapReport.qualityDescription.contains("gaps"))
        
        let wideGapReport = HingeSweepReport(
            observedMin: 0, observedMax: 180, maxGapDegrees: 30,
            restJitterDegrees: 0.5, estimatedHz: 30, monotonicFraction: 1.0,
            statusSequence: [.closed, .partiallyOpen, .fullyOpen], sampleCount: 100
        )
        #expect(wideGapReport.assessQuality() == .attention)
        #expect(wideGapReport.qualityDescription.contains("gaps"))
        
        let unavailableReport = HingeSweepReport(
            observedMin: 0, observedMax: 0, maxGapDegrees: 0,
            restJitterDegrees: 0, estimatedHz: 0, monotonicFraction: 0,
            statusSequence: [], sampleCount: 5
        )
        #expect(unavailableReport.qualityDescription.contains("Not enough"))
    }
}
