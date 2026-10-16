import Foundation
import FoldKit

/// Report of a hinge sweep analysis.
///
/// Contains metrics about the continuity, range, and quality of a hinge sweep.
public struct HingeSweepReport: Codable, Sendable, Equatable {
    /// Minimum angle observed during the sweep (degrees)
    public var observedMin: Double
    
    /// Maximum angle observed during the sweep (degrees)
    public var observedMax: Double
    
    /// Largest gap between consecutive samples (degrees)
    public var maxGapDegrees: Double
    
    /// Jitter observed while the device was at rest (standard deviation in degrees)
    public var restJitterDegrees: Double
    
    /// Estimated sample rate while the hinge was moving (Hz). Gaps longer than
    /// `HingeSampleCollection.idleIntervalThreshold` are left out: the hinge feed only reports
    /// changes, so time spent still says nothing about the rate.
    public var estimatedHz: Double
    
    /// Fraction of the angle travel (degrees moved) that went in the direction of the sweep's
    /// main legs (0.0 to 1.0). A clean "close, then open" sweep is close to 1.0.
    public var monotonicFraction: Double
    
    /// Sequence of posture states observed during the sweep
    public var statusSequence: [FoldPosture]
    
    /// Total samples collected
    public var sampleCount: Int
    
    /// Duration of the sweeps in seconds, first to last reading of each, idle time included
    public var durationSeconds: Double

    /// Number of direction legs found (a guided "close, then open" sweep has 2).
    public var legCount: Int

    /// Largest movement against the expected direction: short reversals outside the main legs,
    /// or single backwards steps inside them (degrees).
    public var maxBacktrackDegrees: Double

    /// Fewest readings per 10° of travel in any main leg; `nil` without a leg. Below
    /// `HingeSweepAnalyzer.minSamplesPer10Degrees` the user moved too fast for the gap check.
    public var minSamplesPer10Degrees: Double?

    /// Change in average angle between the first and last fifth of the ~90° hold, if recorded.
    public var holdDriftDegrees: Double?

    /// Readings during the hold.
    public var holdSampleCount: Int
    
    public init(
        observedMin: Double,
        observedMax: Double,
        maxGapDegrees: Double,
        restJitterDegrees: Double,
        estimatedHz: Double,
        monotonicFraction: Double,
        statusSequence: [FoldPosture],
        sampleCount: Int = 0,
        durationSeconds: Double = 0,
        legCount: Int = 0,
        maxBacktrackDegrees: Double = 0,
        minSamplesPer10Degrees: Double? = nil,
        holdDriftDegrees: Double? = nil,
        holdSampleCount: Int = 0
    ) {
        self.observedMin = observedMin
        self.observedMax = observedMax
        self.maxGapDegrees = maxGapDegrees
        self.restJitterDegrees = restJitterDegrees
        self.estimatedHz = estimatedHz
        self.monotonicFraction = monotonicFraction
        self.statusSequence = statusSequence
        self.sampleCount = sampleCount
        self.durationSeconds = durationSeconds
        self.legCount = legCount
        self.maxBacktrackDegrees = maxBacktrackDegrees
        self.minSamplesPer10Degrees = minSamplesPer10Degrees
        self.holdDriftDegrees = holdDriftDegrees
        self.holdSampleCount = holdSampleCount
    }
    
    /// The observed range of motion
    public var observedRange: Double {
        observedMax - observedMin
    }
    
    /// Whether status transitions were observed (closed → partiallyOpen → fullyOpen or reverse)
    public var hasExpectedTransitions: Bool {
        let hasPartial = statusSequence.contains(.partiallyOpen)
        let hasClosed = statusSequence.contains(.closed)
        let hasOpen = statusSequence.contains(.fullyOpen)
        return hasPartial && (hasClosed || hasOpen)
    }
}
