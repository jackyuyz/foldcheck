import Foundation
import FoldKit

/// Analyzes hinge sweep data to produce a quality report.
///
/// The analyzer checks for:
/// - Monotonic progress (no jumps or reversals)
/// - Gaps in angle coverage
/// - Jitter at rest
/// - Status transitions
/// - Sample rate adequacy (readings per 10° of travel)
public struct HingeSweepAnalyzer: Sendable {
    
    /// Minimum samples required per 10° of sweep for adequate coverage
    public static let minSamplesPer10Degrees: Int = 3
    
    /// Gap threshold above which we flag as potentially problematic (degrees)
    public static let gapWarningThreshold: Double = 15.0
    
    /// Kept as a named constant. Spec AC2 does not Fail a sweep for this gap.
    public static let gapFailThreshold: Double = 25.0

    /// A reversal must exceed this many degrees to start a new direction leg; smaller
    /// back-and-forth is treated as noise inside a leg.
    public static let legHysteresisDegrees: Double = 5.0

    /// A guided sweep ("close to ~20°, then open to flat") has two legs. Extra legs are
    /// non-monotonic movement.
    public static let expectedLegsPerSweep = 2

    /// Movement against the expected direction at or above this is a non-monotonic jump.
    /// Provisional: real hinge noise is undocumented (spec §11 open question 1).
    public static let backtrackWarningThreshold: Double = 10.0

    /// Standard deviation during the ~90° hold above this is Attention. Provisional.
    public static let holdJitterWarningThreshold: Double = 2.0

    /// Drift over the 5 s hold above this is Attention. Provisional.
    public static let holdDriftWarningThreshold: Double = 5.0
    
    public init() {}
    
    /// Analyze a single collection of hinge samples.
    public func analyze(_ samples: HingeSampleCollection) -> HingeSweepReport {
        var report = analyze(sweeps: [samples], hold: nil)
        // Without an explicit hold, estimate rest jitter from the tail of the recording.
        report.restJitterDegrees = calculateRestJitter(samples.samples)
        return report
    }

    /// Analyze a guided run: each sweep separately (so the jump between the end of one sweep
    /// and the start of the next is not a gap), plus an optional hold at ~90°.
    public func analyze(sweeps: [HingeSampleCollection], hold: HingeSampleCollection?) -> HingeSweepReport {
        let analyzed = sweeps.filter { !$0.isEmpty }.map(SweepStats.init)
        guard !analyzed.isEmpty else {
            return HingeSweepReport(
                observedMin: 0,
                observedMax: 0,
                maxGapDegrees: 0,
                restJitterDegrees: 0,
                estimatedHz: 0,
                monotonicFraction: 0,
                statusSequence: [],
                sampleCount: 0,
                durationSeconds: 0,
                holdSampleCount: hold?.count ?? 0
            )
        }

        let totalTravel = analyzed.reduce(0) { $0 + $1.totalTravel }
        let agreeingTravel = analyzed.reduce(0) { $0 + $1.agreeingTravel }
        let intervals = analyzed.reduce(0) { $0 + max($1.count - 1, 0) }
        let duration = analyzed.reduce(0) { $0 + $1.duration }
        // Rate while moving, as in `HingeSampleCollection.estimatedSampleRate`.
        let activeIntervals = analyzed.reduce(0) { $0 + $1.activeIntervals.count }
        let activeDuration = analyzed.reduce(0) { $0 + $1.activeIntervals.duration }
        let estimatedHz = activeDuration > 0
            ? Double(activeIntervals) / activeDuration
            : (duration > 0 ? Double(intervals) / duration : 0)

        var statusSequence: [FoldPosture] = []
        for status in analyzed.flatMap(\.statusSequence) where statusSequence.last != status {
            statusSequence.append(status)
        }

        var restJitter = 0.0
        var holdDrift: Double?
        if let hold, hold.count >= 2 {
            let angles = hold.samples.map(\.degrees)
            restJitter = calculateStandardDeviation(angles)
            // Compare the average of the first and last fifth so one noisy reading isn't drift.
            let window = max(1, angles.count / 5)
            let start = angles.prefix(window).reduce(0, +) / Double(window)
            let end = angles.suffix(window).reduce(0, +) / Double(window)
            holdDrift = abs(end - start)
        }

        return HingeSweepReport(
            observedMin: analyzed.map(\.min).min() ?? 0,
            observedMax: analyzed.map(\.max).max() ?? 0,
            maxGapDegrees: analyzed.map(\.maxGap).max() ?? 0,
            restJitterDegrees: restJitter,
            estimatedHz: estimatedHz,
            monotonicFraction: totalTravel == 0 ? 1.0 : agreeingTravel / totalTravel,
            statusSequence: statusSequence,
            sampleCount: analyzed.reduce(0) { $0 + $1.count },
            durationSeconds: duration,
            legCount: analyzed.reduce(0) { $0 + $1.legCount },
            maxBacktrackDegrees: analyzed.map(\.maxBacktrack).max() ?? 0,
            minSamplesPer10Degrees: analyzed.compactMap(\.samplesPer10Degrees).min(),
            holdDriftDegrees: holdDrift,
            holdSampleCount: hold?.count ?? 0
        )
    }

    /// Splits angles into direction legs: a new leg starts once the angle reverses more than
    /// `legHysteresisDegrees` from the running extreme. Returns index ranges and directions (+1/-1).
    static func legs(_ angles: [Double]) -> [(range: ClosedRange<Int>, direction: Double)] {
        guard angles.count > 1 else { return [] }
        var legs: [(range: ClosedRange<Int>, direction: Double)] = []
        var legStart = 0
        var direction: Double = 0
        var extremeIndex = 0
        for i in 1..<angles.count {
            let angle = angles[i]
            if direction == 0 {
                if abs(angle - angles[legStart]) >= legHysteresisDegrees {
                    direction = angle > angles[legStart] ? 1 : -1
                }
                if direction == 0 || (angle - angles[extremeIndex]) * direction > 0 {
                    extremeIndex = i
                }
                continue
            }
            if (angle - angles[extremeIndex]) * direction > 0 {
                extremeIndex = i
            } else if abs(angles[extremeIndex] - angle) >= legHysteresisDegrees {
                legs.append((legStart...extremeIndex, direction))
                legStart = extremeIndex
                direction = -direction
                extremeIndex = i
            }
        }
        if direction == 0 {
            // Never moved past the hysteresis: one leg in whichever direction it drifted.
            direction = angles[angles.count - 1] >= angles[0] ? 1 : -1
        }
        legs.append((legStart...(angles.count - 1), direction))
        return legs
    }

    /// Per-sweep measurements.
    private struct SweepStats {
        var count: Int
        var duration: TimeInterval
        var activeIntervals: (count: Int, duration: TimeInterval)
        var min: Double
        var max: Double
        var maxGap: Double
        /// Sum of |Δ| over all steps.
        var totalTravel: Double
        /// Sum of |Δ| over steps moving in their main leg's direction.
        var agreeingTravel: Double
        var legCount: Int
        var maxBacktrack: Double
        var samplesPer10Degrees: Double?
        var statusSequence: [FoldPosture]

        init(_ collection: HingeSampleCollection) {
            let samples = collection.samples
            let angles = samples.map(\.degrees)
            count = samples.count
            duration = collection.duration
            activeIntervals = collection.activeIntervals
            min = angles.min() ?? 0
            max = angles.max() ?? 0

            var gap = 0.0
            for i in angles.indices.dropFirst() {
                gap = Swift.max(gap, abs(angles[i] - angles[i - 1]))
            }
            maxGap = gap

            var sequence: [FoldPosture] = []
            for sample in samples where sequence.last != sample.status {
                sequence.append(sample.status)
            }
            statusSequence = sequence

            let legs = HingeSweepAnalyzer.legs(angles)
            legCount = legs.count
            // The main legs are the longest ones; anything else moved the wrong way.
            let travel = { (leg: (range: ClosedRange<Int>, direction: Double)) in
                abs(angles[leg.range.upperBound] - angles[leg.range.lowerBound])
            }
            let mainLegIndices = Set(
                legs.indices
                    .sorted { travel(legs[$0]) > travel(legs[$1]) }
                    .prefix(HingeSweepAnalyzer.expectedLegsPerSweep)
            )

            var directional = 0.0
            var agreeing = 0.0
            var backtrack = 0.0
            var density: Double?
            for (index, leg) in legs.enumerated() {
                let isMain = mainLegIndices.contains(index)
                if !isMain {
                    backtrack = Swift.max(backtrack, travel(leg))
                }
                guard leg.range.count > 1 else { continue }
                for i in (leg.range.lowerBound + 1)...leg.range.upperBound {
                    let delta = angles[i] - angles[i - 1]
                    guard delta != 0 else { continue }
                    directional += abs(delta)
                    if isMain && delta * leg.direction > 0 {
                        agreeing += abs(delta)
                    } else if isMain {
                        backtrack = Swift.max(backtrack, abs(delta))
                    }
                }
                if isMain, travel(leg) >= 10 {
                    let perTen = Double(leg.range.count - 1) / (travel(leg) / 10)
                    density = Swift.min(density ?? perTen, perTen)
                }
            }
            totalTravel = directional
            agreeingTravel = agreeing
            maxBacktrack = backtrack
            samplesPer10Degrees = density
        }
    }
    
    /// Calculate jitter at rest (standard deviation of the last few samples)
    private func calculateRestJitter(_ samples: [HingeSample]) -> Double {
        // Look at the last 10 samples if they're close in time (within 0.5 seconds)
        let restWindowSamples = 10
        let restWindowTime: TimeInterval = 0.5
        
        guard samples.count >= restWindowSamples else {
            return calculateStandardDeviation(samples.map(\.degrees))
        }
        
        let lastSamples = Array(samples.suffix(restWindowSamples))
        let windowDuration = lastSamples.last!.t - lastSamples.first!.t
        
        guard windowDuration <= restWindowTime else {
            // Samples are spread out, not at rest
            return 0
        }
        
        return calculateStandardDeviation(lastSamples.map(\.degrees))
    }
    
    /// Calculate standard deviation of a set of values
    private func calculateStandardDeviation(_ values: [Double]) -> Double {
        guard values.count > 1 else { return 0 }
        
        let mean = values.reduce(0, +) / Double(values.count)
        let squaredDifferences = values.map { pow($0 - mean, 2) }
        let variance = squaredDifferences.reduce(0, +) / Double(values.count - 1)
        return sqrt(variance)
    }
}

// MARK: - Sweep Quality Assessment

public extension HingeSweepReport {
    /// Quality assessment of the sweep
    enum Quality: String, Sendable {
        case pass = "pass"
        case attention = "attention"
        case fail = "fail"
        case unavailable = "unavailable"
    }
    
    /// Assess the overall quality of the sweep
    func assessQuality() -> Quality {
        // Not enough data
        guard sampleCount >= 10 else {
            return .unavailable
        }
        
        // Spec AC2: a 25° gap is Attention, not Fail. No-data stays Unavailable.
        // Gaps at or above the warning threshold, including 25°, are Attention.
        if maxGapDegrees >= HingeSweepAnalyzer.gapWarningThreshold {
            return .attention
        }

        // Check for poor monotonicity (too many direction changes)
        if monotonicFraction < 0.7 {
            return .attention
        }

        // Non-monotonic jumps: moving the wrong way mid-sweep.
        if maxBacktrackDegrees >= HingeSweepAnalyzer.backtrackWarningThreshold {
            return .attention
        }

        // Too fast: too few readings per 10° for the gap check to mean anything.
        if isTooFast {
            return .attention
        }

        // The ~90° hold should be steady.
        if holdIsUnsteady {
            return .attention
        }
        
        // Check for expected transitions
        if !hasExpectedTransitions && observedRange > 90 {
            return .attention
        }
        
        return .pass
    }
    
    /// Fewer than `minSamplesPer10Degrees` readings per 10° in some leg.
    var isTooFast: Bool {
        guard let density = minSamplesPer10Degrees else { return false }
        return density < Double(HingeSweepAnalyzer.minSamplesPer10Degrees)
    }

    /// Jitter or drift during the hold above the provisional thresholds.
    var holdIsUnsteady: Bool {
        guard holdSampleCount >= 2 else { return false }
        return restJitterDegrees > HingeSweepAnalyzer.holdJitterWarningThreshold
            || (holdDriftDegrees ?? 0) > HingeSweepAnalyzer.holdDriftWarningThreshold
    }

    /// Human-readable description of the quality assessment
    var qualityDescription: String {
        switch assessQuality() {
        case .pass:
            return "Hinge sweep completed smoothly with continuous angle readings."
        case .attention:
            var issues: [String] = []
            if maxGapDegrees >= HingeSweepAnalyzer.gapWarningThreshold {
                issues.append("gaps in angle readings (max \(String(format: "%.1f", maxGapDegrees))°)")
            }
            if monotonicFraction < 0.7 {
                issues.append("inconsistent motion direction")
            }
            if maxBacktrackDegrees >= HingeSweepAnalyzer.backtrackWarningThreshold {
                issues.append("readings jumped backwards (\(String(format: "%.1f", maxBacktrackDegrees))°)")
            }
            if isTooFast {
                issues.append("the hinge moved too fast for reliable readings")
            }
            if holdIsUnsteady {
                issues.append("readings were unsteady during the hold")
            }
            if !hasExpectedTransitions && observedRange > 90 {
                issues.append("missing expected status transitions")
            }
            return "Hinge sweep completed with some concerns: \(issues.joined(separator: ", "))."
        case .fail:
            return "Hinge sweep failed for a reason other than a data gap. A 25° gap is Attention, not Fail."
        case .unavailable:
            return "Not enough hinge data was collected to assess."
        }
    }
}
