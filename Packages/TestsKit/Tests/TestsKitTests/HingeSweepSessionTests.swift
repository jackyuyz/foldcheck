import Testing
import Foundation
@testable import TestsKit
import HingeAnalysis

@Suite("Hinge sweep session (T4)")
struct HingeSweepSessionTests {
    let t0 = Date(timeIntervalSinceReferenceDate: 2_000_000)

    func posture(_ angle: Double) -> FoldPosture {
        HingeSweepSession.posture(forManualAngle: angle)
    }

    /// Feeds a 180→20→180 sweep at 30 Hz through either the hinge or the slider.
    func feedSweep(_ session: inout HingeSweepSession, start: Double, manual: Bool = false, skip: ClosedRange<Double>? = nil) {
        var angles: [Double] = Array(stride(from: 180.0, through: 20, by: -1))
        angles += Array(stride(from: 21.0, through: 180, by: 1))
        for (i, angle) in angles.enumerated() where !(skip?.contains(angle) ?? false) {
            let time = t0.addingTimeInterval(start + Double(i) / 30)
            if manual {
                session.recordManual(degrees: angle, at: time)
            } else {
                session.record(FoldState(posture: posture(angle), angleDegrees: angle), at: time)
            }
        }
    }

    func feedHold(_ session: inout HingeSweepSession, start: Double, manual: Bool = false) {
        for i in 0..<150 {
            let angle = 90 + (i.isMultiple(of: 2) ? 0.3 : -0.3)
            let time = t0.addingTimeInterval(start + Double(i) / 30)
            if manual {
                session.recordManual(degrees: angle, at: time)
            } else {
                session.record(FoldState(posture: .partiallyOpen, angleDegrees: angle), at: time)
            }
        }
    }

    func run(manual: Bool = false, gap: ClosedRange<Double>? = nil) -> HingeSweepSession {
        var session = HingeSweepSession()
        session.beginStep(at: t0, current: nil)
        feedSweep(&session, start: 0, manual: manual, skip: gap)
        session.advance()
        session.beginStep(at: t0.addingTimeInterval(20), current: nil)
        feedSweep(&session, start: 20, manual: manual)
        session.advance()
        session.beginStep(at: t0.addingTimeInterval(40), current: nil)
        feedHold(&session, start: 40, manual: manual)
        let finished = session.advance()
        #expect(finished)
        return session
    }

    @Test("Steps run sweep, sweep, hold")
    func steps() {
        var session = HingeSweepSession()
        #expect(session.currentStep == .sweep1)
        session.advance()
        #expect(session.currentStep == .sweep2)
        session.advance()
        #expect(session.currentStep == .hold)
        #expect(session.isLastStep)
        let finished = session.advance()
        #expect(finished)
        #expect(session.isFinished)
    }

    @Test("Clean guided run → Pass with metrics and a chart series")
    func cleanRun() throws {
        let session = run()
        let result = session.result(display: .inner)
        #expect(result.id == .hingeSweep)
        #expect(result.outcome == .pass)
        #expect(result.metrics[TestMetricKey.monotonicFraction] == 1)
        #expect(result.metrics[TestMetricKey.maxGapDegrees] == 1)
        #expect(result.metrics[TestMetricKey.observedMinAngle] == 20)
        #expect(result.metrics[TestMetricKey.observedMaxAngle] == 180)
        #expect(abs((result.metrics[TestMetricKey.sampleRate] ?? 0) - 30) < 0.1)
        #expect(result.metrics[TestMetricKey.legCount] == 4)
        #expect((result.metrics[TestMetricKey.restJitter] ?? 99) < 0.5)
        #expect((result.metrics[TestMetricKey.holdAngle] ?? 0).rounded() == 90)
        #expect(result.metrics[TestMetricKey.manualInput] == 0)
        #expect(!result.series.isEmpty)
        #expect(result.series.count <= HingeSweepSession.maxSeriesPoints + 9)
        #expect(Set(result.series.map(\.segment)) == [0, 1, 2])
        // The series keeps the extremes of each sweep.
        let sweep1 = result.series.filter { $0.segment == 0 }.map(\.value)
        #expect(sweep1.min() == 20)
        #expect(sweep1.last == 180)
    }

    @Test("Waiting before moving: non-zero rate, and each step charted from its first movement")
    func idleLeadIn() {
        var session = HingeSweepSession()
        // The feed only reports changes: the seeded starting angle, then nothing for 14 minutes.
        session.beginStep(at: t0, current: FoldState(posture: .fullyOpen, angleDegrees: 180))
        feedSweep(&session, start: 840)
        session.advance()
        session.beginStep(at: t0.addingTimeInterval(900), current: FoldState(posture: .fullyOpen, angleDegrees: 180))
        feedSweep(&session, start: 905)
        session.advance()
        session.beginStep(at: t0.addingTimeInterval(950), current: nil)
        feedHold(&session, start: 950)
        session.advance()

        let result = session.result(display: .inner)
        #expect(result.outcome == .pass)
        #expect(abs((result.metrics[TestMetricKey.sampleRate] ?? 0) - 30) < 0.1)
        for segment in 0...2 {
            let points = result.series.filter { $0.segment == segment }
            #expect(points.first?.t == 0)
            #expect((points.last?.t ?? 99) < 12)
        }
        #expect(result.series.first { $0.segment == 0 }?.value == 180)
    }

    @Test("The starting angle is charted one reading interval before the first movement")
    func chartLeadIn() {
        var sweep = HingeSampleCollection(samples: [HingeSample(degrees: 180, status: .fullyOpen, t: 0)])
        for i in 1...60 {
            sweep.append(HingeSample(degrees: 180 - Double(i), status: .partiallyOpen, t: 600 + Double(i) / 30))
        }
        let charted = HingeSweepSession.chartSamples(sweep, fromFirstMovement: true)
        #expect(charted.count == 61)
        #expect(charted[0].t == 0)
        #expect(charted[0].degrees == 180)
        #expect(abs(charted[1].t - 1.0 / 30) < 0.001)
        #expect(abs(charted[60].t - 2) < 0.001)
        // The hold is charted from its own start, still readings included.
        let hold = HingeSweepSession.chartSamples(sweep, fromFirstMovement: false)
        #expect(hold.count == 61)
        #expect(hold[1].t > 600)
    }

    @Test("A 25° gap → Attention (AC2)")
    func gappyRun() {
        let result = run(gap: 81...105).result(display: .inner)
        #expect(result.outcome == .attention)
        #expect((result.metrics[TestMetricKey.maxGapDegrees] ?? 0) >= 25)
    }

    @Test("The slider gives identical results, flagged as manual input")
    func manualIsIdentical() {
        let hinge = run().result(display: .inner, finishedAt: t0)
        let manual = run(manual: true).result(display: .inner, finishedAt: t0)
        #expect(manual.outcome == hinge.outcome)
        var hingeMetrics = hinge.metrics
        var manualMetrics = manual.metrics
        hingeMetrics[TestMetricKey.manualInput] = nil
        manualMetrics[TestMetricKey.manualInput] = nil
        #expect(manualMetrics == hingeMetrics)
        #expect(manual.series == hinge.series)
        #expect(manual.metrics[TestMetricKey.manualInput] == 1)
    }

    @Test("No readings at all → Unavailable, never Fail (AC2)")
    func noReadings() {
        var session = HingeSweepSession()
        session.beginStep(at: t0, current: FoldState(posture: .fullyOpen, angleDegrees: nil))
        session.record(FoldState.noHinge, at: t0.addingTimeInterval(1))
        #expect(!session.receivedHingeReading)
        session.advance()
        session.advance()
        session.advance()
        let result = session.result(display: .inner)
        #expect(result.outcome == .unavailable)
        #expect(result.metrics[TestMetricKey.hingeSamples] == 0)
        #expect(result.metrics[TestMetricKey.maxGapDegrees] == nil)
    }

    @Test("A hinge that never moves (static reading) → Unavailable")
    func staticHinge() {
        var session = HingeSweepSession()
        let open = FoldState(posture: .fullyOpen, angleDegrees: 180)
        for step in 0..<3 {
            session.beginStep(at: t0.addingTimeInterval(Double(step) * 10), current: open)
            session.advance()
        }
        #expect(session.receivedHingeReading)
        #expect(session.result(display: .inner).outcome == .unavailable)
    }

    @Test("beginStep seeds the current reading and clears a retried step")
    func seedAndRetry() {
        var session = HingeSweepSession()
        session.beginStep(at: t0, current: FoldState(posture: .fullyOpen, angleDegrees: 180))
        #expect(session.currentSamples.count == 1)
        session.record(FoldState(posture: .partiallyOpen, angleDegrees: 150), at: t0.addingTimeInterval(1))
        #expect(session.currentTravel == 30)
        session.beginStep(at: t0.addingTimeInterval(2), current: nil)
        #expect(session.currentSamples.isEmpty)
        session.restart()
        #expect(session == HingeSweepSession())
    }

    @Test("Speed meter flags moving faster than the reading rate allows")
    func speed() {
        var session = HingeSweepSession()
        // 30 Hz readings: limit is 30 * 10 / 3 = 100°/s.
        for i in 0..<15 {
            session.record(FoldState(posture: .partiallyOpen, angleDegrees: 100 + Double(i)), at: t0.addingTimeInterval(Double(i) / 30))
        }
        #expect(abs((session.speedLimit ?? 0) - 100) < 0.1)
        #expect(abs((session.speed() ?? 0) - 30) < 0.5)
        #expect(!session.isTooFast)
        for i in 15..<30 {
            session.record(FoldState(posture: .partiallyOpen, angleDegrees: 115 + Double(i - 14) * 5), at: t0.addingTimeInterval(Double(i) / 30))
        }
        #expect(session.isTooFast)
    }

    @Test("Manual angles map to postures with the mock sweep cut-offs")
    func manualPosture() {
        #expect(HingeSweepSession.posture(forManualAngle: 5) == .closed)
        #expect(HingeSweepSession.posture(forManualAngle: 90) == .partiallyOpen)
        #expect(HingeSweepSession.posture(forManualAngle: 175) == .fullyOpen)
    }
}

@Suite("Outcome and result additions")
struct OutcomeAdditionsTests {
    @Test("Unavailable is neither completed nor scored")
    func unavailable() {
        #expect(!TestOutcome.unavailable.isCompleted)
        #expect(TestOutcome.unavailable.score == -1)
        #expect(TestOutcome.unavailable.rawValue == "unavailable")
        var session = InspectionSession(deviceModel: "x", osVersion: "y", hasHinge: true)
        session.setResult(TestResult(id: .pixels, outcome: .pass))
        session.setResult(TestResult(id: .hingeSweep, outcome: .unavailable))
        #expect(session.overallScore == 100)
        #expect(session.overallStatus == .pass)
    }

    @Test("Results without a series still decode")
    func legacyDecode() throws {
        let json = #"{"id":"pixels","outcome":"pass","metrics":{},"notes":"","attachments":[],"finishedAt":0}"#
        let result = try JSONDecoder().decode(TestResult.self, from: Data(json.utf8))
        #expect(result.series.isEmpty)
        let withSeries = TestResult(id: .hingeSweep, outcome: .pass, series: [TestSeriesPoint(t: 1, value: 90, segment: 2)])
        let decoded = try JSONDecoder().decode(TestResult.self, from: JSONEncoder().encode(withSeries))
        #expect(decoded == withSeries)
    }
}
