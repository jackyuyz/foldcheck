import Foundation
import FoldKit

/// Analyzes hinge sweep data to produce a quality report.
///
/// The analyzer checks for:
/// - Monotonic progress (no jumps or reversals)
/// - Gaps in angle coverage
/// - Jitter at rest
/// - Status transitions
/// - Sample rate adequacy
public struct HingeSweepAnalyzer: Sendable {
    
    /// Minimum samples required per 10° of sweep for adequate coverage
    public static let minSamplesPer10Degrees: Int = 3
    
    /// Gap threshold above which we flag as potentially problematic (degrees)
    public static let gapWarningThreshold: Double = 15.0
    
    /// Gap threshold above which we flag as a significant issue (degrees)
    public static let gapFailThreshold: Double = 25.0
    
    public init() {}
    
    /// Analyze a collection of hinge samples
    public func analyze(_ samples: HingeSampleCollection) -> HingeSweepReport {
        guard !samples.isEmpty else {
            return HingeSweepReport(
                observedMin: 0,
                observedMax: 0,
                maxGapDegrees: 0,
                restJitterDegrees: 0,
                estimatedHz: 0,
                monotonicFraction: 0,
                statusSequence: [],
                sampleCount: 0,
                durationSeconds: 0
            )
        }
        
        let angles = samples.samples.map(\.degrees)
        let observedMin = angles.min() ?? 0
        let observedMax = angles.max() ?? 0
        
        // Calculate max gap between consecutive samples
        let maxGap = calculateMaxGap(angles)
        
        // Calculate monotonic fraction
        let monotonicFraction = calculateMonotonicFraction(angles)
        
        // Calculate rest jitter (standard deviation of last N samples if at rest)
        let restJitter = calculateRestJitter(samples.samples)
        
        // Extract unique status sequence (deduplicated consecutive values)
        let statusSequence = extractStatusSequence(samples.samples)
        
        return HingeSweepReport(
            observedMin: observedMin,
            observedMax: observedMax,
            maxGapDegrees: maxGap,
            restJitterDegrees: restJitter,
            estimatedHz: samples.estimatedSampleRate,
            monotonicFraction: monotonicFraction,
            statusSequence: statusSequence,
            sampleCount: samples.count,
            durationSeconds: samples.duration
        )
    }
    
    /// Calculate the maximum gap between consecutive angle readings
    private func calculateMaxGap(_ angles: [Double]) -> Double {
        guard angles.count > 1 else { return 0 }
        
        var maxGap: Double = 0
        for i in 1..<angles.count {
            let gap = abs(angles[i] - angles[i-1])
            maxGap = max(maxGap, gap)
        }
        return maxGap
    }
    
    /// Calculate what fraction of the sweep was monotonic (increasing or decreasing)
    ///
    /// A perfect sweep would be 1.0 (all samples moving in the same direction)
    private func calculateMonotonicFraction(_ angles: [Double]) -> Double {
        guard angles.count > 2 else { return 1.0 }
        
        var increasingCount = 0
        var decreasingCount = 0
        
        for i in 1..<angles.count {
            let delta = angles[i] - angles[i-1]
            if delta > 0 {
                increasingCount += 1
            } else if delta < 0 {
                decreasingCount += 1
            }
            // delta == 0 counts as neither
        }
        
        let totalDirectionalMoves = increasingCount + decreasingCount
        guard totalDirectionalMoves > 0 else { return 1.0 }
        
        let dominantDirection = max(increasingCount, decreasingCount)
        return Double(dominantDirection) / Double(totalDirectionalMoves)
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
    
    /// Extract the sequence of status changes (deduplicated)
    private func extractStatusSequence(_ samples: [HingeSample]) -> [FoldPosture] {
        var sequence: [FoldPosture] = []
        
        for sample in samples {
            if sequence.last != sample.status {
                sequence.append(sample.status)
            }
        }
        
        return sequence
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
        
        // Check for significant gaps
        if maxGapDegrees >= HingeSweepAnalyzer.gapFailThreshold {
            return .fail
        }
        
        // Check for poor monotonicity (too many direction changes)
        if monotonicFraction < 0.7 {
            return .attention
        }
        
        // Check for warning-level gaps
        if maxGapDegrees >= HingeSweepAnalyzer.gapWarningThreshold {
            return .attention
        }
        
        // Check for expected transitions
        if !hasExpectedTransitions && observedRange > 90 {
            return .attention
        }
        
        return .pass
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
            if !hasExpectedTransitions && observedRange > 90 {
                issues.append("missing expected status transitions")
            }
            return "Hinge sweep completed with some concerns: \(issues.joined(separator: ", "))."
        case .fail:
            return "Hinge sweep showed significant gaps (\(String(format: "%.1f", maxGapDegrees))°) suggesting potential issues."
        case .unavailable:
            return "Not enough hinge data was collected to assess."
        }
    }
}
