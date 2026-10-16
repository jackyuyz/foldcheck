import Foundation
import FoldKit

/// A single sample of hinge state at a point in time.
public struct HingeSample: Equatable, Sendable, Codable {
    /// The angle in degrees as reported by the system
    public var degrees: Double
    
    /// The posture at this sample point
    public var status: FoldPosture
    
    /// Time interval since the start of recording (seconds)
    public var t: TimeInterval
    
    public init(degrees: Double, status: FoldPosture, t: TimeInterval) {
        self.degrees = degrees
        self.status = status
        self.t = t
    }
}

/// Collection of hinge samples for analysis.
public struct HingeSampleCollection: Sendable, Equatable {
    public var samples: [HingeSample]
    
    public init(samples: [HingeSample] = []) {
        self.samples = samples
    }
    
    public mutating func append(_ sample: HingeSample) {
        samples.append(sample)
    }
    
    public var isEmpty: Bool { samples.isEmpty }
    public var count: Int { samples.count }
    
    /// Total duration of the sample collection
    public var duration: TimeInterval {
        guard let first = samples.first, let last = samples.last else { return 0 }
        return last.t - first.t
    }
    
    /// Gaps between consecutive readings longer than this are the hinge sitting still, not
    /// the reading rate (seconds).
    public static let idleIntervalThreshold: TimeInterval = 1.0

    /// Intervals between consecutive readings of at most `idleIntervalThreshold`, and their
    /// total length.
    public var activeIntervals: (count: Int, duration: TimeInterval) {
        var count = 0
        var total: TimeInterval = 0
        for i in samples.indices.dropFirst() {
            let dt = samples[i].t - samples[i - 1].t
            guard dt <= Self.idleIntervalThreshold else { continue }
            count += 1
            total += dt
        }
        return (count, total)
    }

    /// Estimated sample rate in Hz while the hinge is moving.
    ///
    /// The hinge feed is event-driven: it only delivers a reading when the angle changes, so a
    /// hinge left still for minutes would dilute count / duration towards 0 Hz. Idle gaps are
    /// left out instead. This uses count / duration over the active intervals rather than the
    /// median interval, which bursts of near-simultaneous readings could pull towards 0 s.
    /// Falls back to the plain average when every interval is idle.
    public var estimatedSampleRate: Double {
        guard samples.count > 1, duration > 0 else { return 0 }
        let active = activeIntervals
        guard active.duration > 0 else { return Double(samples.count - 1) / duration }
        return Double(active.count) / active.duration
    }
    
    /// Minimum angle observed
    public var minAngle: Double? {
        samples.map(\.degrees).min()
    }
    
    /// Maximum angle observed
    public var maxAngle: Double? {
        samples.map(\.degrees).max()
    }
    
    /// Observed angle range
    public var angleRange: ClosedRange<Double>? {
        guard let min = minAngle, let max = maxAngle else { return nil }
        return min...max
    }
}
