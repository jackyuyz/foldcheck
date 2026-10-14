import Foundation
import FoldKit
import HingeAnalysis

/// The guided steps of the hinge test (T4).
public enum HingeSweepStep: Int, Codable, Sendable, CaseIterable, Equatable {
    /// "Close slowly to ~20°, then open slowly to flat."
    case sweep1
    /// The same again.
    case sweep2
    /// "Hold at ~90° for 5 s."
    case hold

    public var isSweep: Bool { self != .hold }
}

/// State of one hinge test run (T4): readings per step, then a `HingeSweepReport`.
///
/// Readings come from the fold state provider, or from the on-screen slider (the non-hinge
/// control every hinge interaction needs). Both go through the same analysis; slider input is
/// flagged in the result so a report never passes it off as a hinge measurement.
public struct HingeSweepSession: Sendable, Equatable {
    public static let holdDuration: TimeInterval = 5
    /// Upper bound on stored chart points across all steps.
    public static let maxSeriesPoints = 450

    public let steps = HingeSweepStep.allCases
    public private(set) var stepIndex = 0
    public private(set) var sweeps = [HingeSampleCollection(), HingeSampleCollection()]
    public private(set) var hold = HingeSampleCollection()
    public private(set) var isFinished = false
    /// Any slider input was used.
    public private(set) var usedManualInput = false
    /// Any reading with an angle arrived from the hinge.
    public private(set) var receivedHingeReading = false
    private var origin: Date?

    public init() {}

    public var currentStep: HingeSweepStep {
        steps[min(stepIndex, steps.count - 1)]
    }

    public var isLastStep: Bool {
        stepIndex >= steps.count - 1
    }

    /// Readings recorded for the step on screen.
    public var currentSamples: HingeSampleCollection {
        switch currentStep {
        case .sweep1: return sweeps[0]
        case .sweep2: return sweeps[1]
        case .hold: return hold
        }
    }

    // MARK: Recording

    /// Starts the current step, seeding it with the current reading so a step where the hinge
    /// never moves still has its starting angle.
    public mutating func beginStep(at time: Date, current: FoldState?) {
        if origin == nil { origin = time }
        setCurrentSamples(HingeSampleCollection())
        if let current {
            record(current, at: time)
        }
    }

    /// Records a hinge reading. States without an angle (no hinge, unknown) are ignored.
    public mutating func record(_ state: FoldState, at time: Date) {
        guard !isFinished, state.hasHinge, let degrees = state.angleDegrees else { return }
        receivedHingeReading = true
        append(HingeSample(degrees: degrees, status: state.posture, t: elapsed(at: time)))
    }

    /// Records an angle from the on-screen slider. Same analysis as hinge readings.
    public mutating func recordManual(degrees: Double, at time: Date) {
        guard !isFinished else { return }
        usedManualInput = true
        append(HingeSample(degrees: degrees, status: Self.posture(forManualAngle: degrees), t: elapsed(at: time)))
    }

    /// The posture a slider angle stands for, using the same cut-offs as the mock sweep.
    public static func posture(forManualAngle degrees: Double) -> FoldPosture {
        degrees < 10 ? .closed : (degrees > 170 ? .fullyOpen : .partiallyOpen)
    }

    private mutating func append(_ sample: HingeSample) {
        var samples = currentSamples
        samples.append(sample)
        setCurrentSamples(samples)
    }

    private mutating func setCurrentSamples(_ samples: HingeSampleCollection) {
        switch currentStep {
        case .sweep1: sweeps[0] = samples
        case .sweep2: sweeps[1] = samples
        case .hold: hold = samples
        }
    }

    private mutating func elapsed(at time: Date) -> TimeInterval {
        if origin == nil { origin = time }
        return time.timeIntervalSince(origin ?? time)
    }

    // MARK: Progress

    /// Moves to the next step. Returns true when the last step is done.
    @discardableResult
    public mutating func advance() -> Bool {
        if isLastStep {
            isFinished = true
        } else {
            stepIndex += 1
        }
        return isFinished
    }

    /// "Try again": discards everything and starts over at sweep 1.
    public mutating func restart() {
        self = HingeSweepSession()
    }

    /// The angle moved during the current step (max − min), 0 without readings.
    public var currentTravel: Double {
        guard let range = currentSamples.angleRange else { return 0 }
        return range.upperBound - range.lowerBound
    }

    /// Hinge speed over the last `window` seconds of the current step (degrees per second).
    public func speed(window: TimeInterval = 0.5) -> Double? {
        let samples = currentSamples.samples
        guard let last = samples.last else { return nil }
        let recent = samples.filter { last.t - $0.t <= window }
        guard let first = recent.first, last.t - first.t > 0.05 else { return nil }
        return abs(last.degrees - first.degrees) / (last.t - first.t)
    }

    /// The fastest speed that still gives `minSamplesPer10Degrees` at the observed reading rate.
    public var speedLimit: Double? {
        let hz = currentSamples.estimatedSampleRate
        guard hz > 0, currentSamples.count >= 5 else { return nil }
        return hz * 10 / Double(HingeSweepAnalyzer.minSamplesPer10Degrees)
    }

    /// "Too fast, go slower".
    public var isTooFast: Bool {
        guard let speed = speed(), let limit = speedLimit else { return false }
        return speed > limit
    }

    // MARK: Result

    public var report: HingeSweepReport {
        HingeSweepAnalyzer().analyze(sweeps: sweeps, hold: hold)
    }

    /// Pass/Attention from the analysis; Unavailable when there wasn't enough data (never Fail).
    public var outcome: TestOutcome {
        switch report.assessQuality() {
        case .pass: return .pass
        case .attention: return .attention
        case .fail: return .fail
        case .unavailable: return .unavailable
        }
    }

    /// Hold angle: the average reading during the hold.
    public var holdAngle: Double? {
        guard !hold.isEmpty else { return nil }
        return hold.samples.map(\.degrees).reduce(0, +) / Double(hold.count)
    }

    /// Readings downsampled for the chart; segment = step index.
    public var series: [TestSeriesPoint] {
        let segments = [sweeps[0], sweeps[1], hold]
        let perSegment = Self.maxSeriesPoints / segments.count
        return segments.enumerated().flatMap { index, collection -> [TestSeriesPoint] in
            let samples = collection.samples
            guard !samples.isEmpty else { return [] }
            let stride = max(1, Int((Double(samples.count) / Double(perSegment)).rounded(.up)))
            var indices = Set(Swift.stride(from: 0, to: samples.count, by: stride))
            // Keep the end and the extremes so the chart shows the real range.
            indices.insert(samples.count - 1)
            if let low = samples.indices.min(by: { samples[$0].degrees < samples[$1].degrees }) { indices.insert(low) }
            if let high = samples.indices.max(by: { samples[$0].degrees < samples[$1].degrees }) { indices.insert(high) }
            return indices.sorted().map { TestSeriesPoint(t: samples[$0].t, value: samples[$0].degrees, segment: index) }
        }
    }

    public func result(display: DisplayKind?, notes: String = "", finishedAt: Date = .now) -> TestResult {
        let report = report
        var metrics: [String: Double] = [
            TestMetricKey.hingeSamples: Double(report.sampleCount),
            TestMetricKey.manualInput: usedManualInput ? 1 : 0,
        ]
        if report.sampleCount > 0 {
            metrics[TestMetricKey.observedMinAngle] = report.observedMin
            metrics[TestMetricKey.observedMaxAngle] = report.observedMax
            metrics[TestMetricKey.maxGapDegrees] = report.maxGapDegrees
            metrics[TestMetricKey.monotonicFraction] = report.monotonicFraction
            metrics[TestMetricKey.sampleRate] = report.estimatedHz
            metrics[TestMetricKey.legCount] = Double(report.legCount)
            metrics[TestMetricKey.maxBacktrack] = report.maxBacktrackDegrees
        }
        if let density = report.minSamplesPer10Degrees {
            metrics[TestMetricKey.samplesPer10Degrees] = density
        }
        if report.holdSampleCount >= 2 {
            metrics[TestMetricKey.restJitter] = report.restJitterDegrees
            metrics[TestMetricKey.holdDrift] = report.holdDriftDegrees ?? 0
        }
        if let holdAngle {
            metrics[TestMetricKey.holdAngle] = holdAngle
        }
        return TestResult(
            id: .hingeSweep,
            outcome: outcome,
            metrics: metrics,
            notes: notes,
            display: display,
            finishedAt: finishedAt,
            series: series
        )
    }
}
