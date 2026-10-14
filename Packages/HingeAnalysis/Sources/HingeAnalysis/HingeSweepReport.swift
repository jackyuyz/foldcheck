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
    
    /// Estimated sample rate (Hz)
    public var estimatedHz: Double
    
    /// Fraction of the sweep that was monotonic (0.0 to 1.0)
    /// A clean sweep should be close to 1.0
    public var monotonicFraction: Double
    
    /// Sequence of posture states observed during the sweep
    public var statusSequence: [FoldPosture]
    
    /// Total samples collected
    public var sampleCount: Int
    
    /// Duration of the sweep in seconds
    public var durationSeconds: Double
    
    public init(
        observedMin: Double,
        observedMax: Double,
        maxGapDegrees: Double,
        restJitterDegrees: Double,
        estimatedHz: Double,
        monotonicFraction: Double,
        statusSequence: [FoldPosture],
        sampleCount: Int = 0,
        durationSeconds: Double = 0
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
