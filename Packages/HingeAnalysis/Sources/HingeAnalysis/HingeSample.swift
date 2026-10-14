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
    
    /// Estimated sample rate in Hz
    public var estimatedSampleRate: Double {
        guard samples.count > 1, duration > 0 else { return 0 }
        return Double(samples.count - 1) / duration
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
