import Testing
import Foundation
@testable import HingeAnalysis

/// Synthetic guided runs (spec §8 / AC2): two "close to ~20°, then open to flat" sweeps
/// plus a 5 s hold at ~90°.
@Suite("Guided hinge runs (AC2)")
struct GuidedSweepTests {
    let analyzer = HingeSweepAnalyzer()

    static func posture(_ angle: Double) -> FoldPosture {
        angle < 10 ? .closed : (angle > 170 ? .fullyOpen : .partiallyOpen)
    }

    /// Angles through the given waypoints in 1° steps at 30 Hz.
    static func sweep(
        _ waypoints: [Double],
        hz: Double = 30,
        step: Double = 1,
        posture: (Double) -> FoldPosture = GuidedSweepTests.posture,
        edit: (Int, Double) -> Double? = { $1 }
    ) -> HingeSampleCollection {
        var angles: [Double] = [waypoints[0]]
        for (from, to) in zip(waypoints, waypoints.dropFirst()) {
            let n = Int((abs(to - from) / step).rounded())
            for i in 1...max(n, 1) {
                angles.append(from + (to - from) * Double(i) / Double(max(n, 1)))
            }
        }
        var collection = HingeSampleCollection()
        var t = 0.0
        for (index, angle) in angles.enumerated() {
            guard let edited = edit(index, angle) else { continue }
            collection.append(HingeSample(degrees: edited, status: posture(edited), t: t))
            t += 1 / hz
        }
        return collection
    }

    static func hold(at angle: Double, wobble: Double = 0.2, drift: Double = 0) -> HingeSampleCollection {
        var collection = HingeSampleCollection()
        for i in 0..<150 {
            let value = angle + (i.isMultiple(of: 2) ? wobble : -wobble) + drift * Double(i) / 149
            collection.append(HingeSample(degrees: value, status: .partiallyOpen, t: Double(i) / 30))
        }
        return collection
    }

    var cleanSweep: HingeSampleCollection { Self.sweep([180, 20, 180]) }

    @Test("Clean guided run → Pass, even though each sweep reverses direction")
    func clean() {
        let report = analyzer.analyze(sweeps: [cleanSweep, cleanSweep], hold: Self.hold(at: 90))
        #expect(report.assessQuality() == .pass)
        #expect(report.monotonicFraction == 1.0)
        #expect(report.legCount == 4)
        #expect(report.maxGapDegrees == 1.0)
        #expect(report.maxBacktrackDegrees == 0)
        #expect(report.observedMin == 20)
        #expect(report.observedMax == 180)
        #expect(abs(report.estimatedHz - 30) < 0.01)
        #expect(report.holdSampleCount == 150)
        #expect(report.restJitterDegrees < 0.5)
        #expect((report.holdDriftDegrees ?? 99) < 0.1)
        #expect(report.statusSequence == [.fullyOpen, .partiallyOpen, .fullyOpen, .partiallyOpen, .fullyOpen])
    }

    @Test("The jump from the end of sweep 1 to the start of sweep 2 is not a gap")
    func sweepsAnalyzedSeparately() {
        let up = Self.sweep([10, 180])
        let report = analyzer.analyze(sweeps: [up, up], hold: nil)
        #expect(report.maxGapDegrees == 1.0)
        #expect(report.assessQuality() == .pass)
    }

    @Test("A 25° gap → Attention, never Fail")
    func gap() {
        let gappy = Self.sweep([180, 20, 180], edit: { _, angle in
            (angle > 80 && angle < 105) ? nil : angle
        })
        let report = analyzer.analyze(sweeps: [gappy, cleanSweep], hold: Self.hold(at: 90))
        #expect(report.maxGapDegrees >= 25)
        #expect(report.assessQuality() == .attention)
    }

    @Test("A non-monotonic jump backwards mid-sweep → Attention")
    func backwardsJump() {
        // While opening, one reading jumps back 12° and then continues.
        let jumpy = Self.sweep([180, 20, 180], edit: { index, angle in
            index == 250 ? angle - 12 : angle
        })
        let report = analyzer.analyze(sweeps: [jumpy, cleanSweep], hold: Self.hold(at: 90))
        #expect(report.maxBacktrackDegrees >= 10)
        #expect(report.assessQuality() == .attention)
    }

    @Test("Wobbling back and forth → Attention")
    func wobble() {
        let wobbly = Self.sweep([180, 20, 60, 30, 70, 40, 180])
        let report = analyzer.analyze(sweeps: [wobbly], hold: nil)
        #expect(report.legCount > 2)
        #expect(report.maxBacktrackDegrees >= 30)
        #expect(report.assessQuality() == .attention)
    }

    @Test("Small sensor noise inside a leg is not a backtrack")
    func noise() {
        let noisy = Self.sweep([180, 20, 180], edit: { index, angle in
            angle + (index.isMultiple(of: 2) ? 0.4 : -0.4)
        })
        let report = analyzer.analyze(sweeps: [noisy, noisy], hold: Self.hold(at: 90))
        #expect(report.legCount == 4)
        #expect(report.maxBacktrackDegrees < 1)
        #expect(report.assessQuality() == .pass)
    }

    @Test("No data → Unavailable, never Fail")
    func noData() {
        let report = analyzer.analyze(sweeps: [HingeSampleCollection(), HingeSampleCollection()], hold: HingeSampleCollection())
        #expect(report.sampleCount == 0)
        #expect(report.assessQuality() == .unavailable)
        let still = analyzer.analyze(sweeps: [Self.sweep([180, 180])], hold: nil)
        #expect(still.assessQuality() == .unavailable)
    }

    @Test("A smaller observed range (40°–150°) is reported, not judged")
    func partialRange() {
        // This device reports "flat" at 150°: the range is undocumented, so that's fine.
        let partial = Self.sweep([150, 40, 150], posture: { $0 >= 150 ? .fullyOpen : .partiallyOpen })
        let report = analyzer.analyze(sweeps: [partial, partial], hold: Self.hold(at: 90))
        #expect(report.observedMin == 40)
        #expect(report.observedMax == 150)
        #expect(report.assessQuality() == .pass)
    }

    @Test("Too fast (fewer than 3 readings per 10°) → Attention")
    func tooFast() {
        let fast = Self.sweep([180, 20, 180], step: 5)
        let report = analyzer.analyze(sweeps: [fast], hold: nil)
        #expect((report.minSamplesPer10Degrees ?? 99) < 3)
        #expect(report.isTooFast)
        #expect(report.assessQuality() == .attention)
        #expect(report.qualityDescription.contains("too fast"))
    }

    @Test("Drift or jitter during the hold → Attention")
    func unsteadyHold() {
        let drifting = analyzer.analyze(sweeps: [cleanSweep], hold: Self.hold(at: 90, drift: 8))
        #expect((drifting.holdDriftDegrees ?? 0) > 6)
        #expect(drifting.assessQuality() == .attention)
        let shaky = analyzer.analyze(sweeps: [cleanSweep], hold: Self.hold(at: 90, wobble: 3))
        #expect(shaky.restJitterDegrees > 2)
        #expect(shaky.assessQuality() == .attention)
    }

    @Test("Waiting before the first movement doesn't drag the rate to 0 Hz")
    func idleLeadIn() {
        // The real hinge feed reports changes only: the seeded starting reading, then nothing
        // until the user moves ~14 minutes later.
        var sweep = HingeSampleCollection(samples: [HingeSample(degrees: 180, status: .fullyOpen, t: 0)])
        for sample in cleanSweep.samples {
            sweep.append(HingeSample(degrees: sample.degrees, status: sample.status, t: 840 + sample.t))
        }
        let report = analyzer.analyze(sweeps: [sweep, cleanSweep], hold: Self.hold(at: 90))
        #expect(report.durationSeconds > 840)
        #expect(abs(report.estimatedHz - 30) < 0.01)
        #expect(report.assessQuality() == .pass)
    }

    @Test("Legs are split with hysteresis")
    func legs() {
        let angles: [Double] = [180, 150, 100, 50, 20, 22, 21, 60, 120, 180]
        let legs = HingeSweepAnalyzer.legs(angles)
        #expect(legs.count == 2)
        #expect(legs[0].direction == -1)
        #expect(legs[0].range == 0...4)
        #expect(legs[1].direction == 1)
        #expect(legs[1].range == 4...9)
        #expect(HingeSweepAnalyzer.legs([5]).isEmpty)
    }

    @Test("New report fields survive Codable")
    func codable() throws {
        let report = analyzer.analyze(sweeps: [cleanSweep], hold: Self.hold(at: 90))
        let decoded = try JSONDecoder().decode(HingeSweepReport.self, from: JSONEncoder().encode(report))
        #expect(decoded == report)
    }
}
