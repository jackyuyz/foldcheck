import Foundation
import FoldKit

/// Tracks fold cycles (closed→open transitions) while the app is in the foreground.
///
/// Important: This counter only tracks folds observed while FoldCheck is running.
/// It does NOT represent the device's lifetime fold count (which is not available to apps).
public actor FoldCounter {
    /// Statistics about observed fold activity
    public struct Stats: Codable, Sendable, Equatable {
        /// Number of closed→open transitions observed
        public var foldCount: Int
        
        /// Total time spent in closed state (seconds)
        public var closedDuration: TimeInterval
        
        /// Total time spent in open state (seconds)
        public var openDuration: TimeInterval
        
        /// Total time spent in partially open state (seconds)
        public var partialDuration: TimeInterval
        
        /// When tracking started
        public var startedAt: Date
        
        /// When tracking last updated
        public var updatedAt: Date
        
        public init(
            foldCount: Int = 0,
            closedDuration: TimeInterval = 0,
            openDuration: TimeInterval = 0,
            partialDuration: TimeInterval = 0,
            startedAt: Date = .now,
            updatedAt: Date = .now
        ) {
            self.foldCount = foldCount
            self.closedDuration = closedDuration
            self.openDuration = openDuration
            self.partialDuration = partialDuration
            self.startedAt = startedAt
            self.updatedAt = updatedAt
        }
        
        /// Total observation time
        public var totalDuration: TimeInterval {
            closedDuration + openDuration + partialDuration
        }
        
        /// Percentage of time spent on outer display (closed)
        public var closedPercent: Double {
            guard totalDuration > 0 else { return 0 }
            return closedDuration / totalDuration * 100
        }
        
        /// Percentage of time spent on inner display (open or partial)
        public var innerPercent: Double {
            guard totalDuration > 0 else { return 0 }
            return (openDuration + partialDuration) / totalDuration * 100
        }
    }
    
    private var stats: Stats
    private var lastPosture: FoldPosture?
    private var lastTransitionTime: Date?
    private var isTracking: Bool = false
    
    public init() {
        self.stats = Stats()
    }
    
    /// Start tracking fold events
    public func startTracking() {
        guard !isTracking else { return }
        isTracking = true
        stats.startedAt = .now
        lastTransitionTime = .now
    }
    
    /// Stop tracking fold events
    public func stopTracking() {
        guard isTracking else { return }
        // Record final duration for current state
        if let lastTime = lastTransitionTime, let posture = lastPosture {
            let duration = Date.now.timeIntervalSince(lastTime)
            addDuration(duration, for: posture)
        }
        isTracking = false
    }
    
    /// Process a new fold state
    public func process(_ state: FoldState) {
        guard isTracking else { return }
        
        let now = Date.now
        stats.updatedAt = now
        
        // Record duration in previous state
        if let lastTime = lastTransitionTime, let previousPosture = lastPosture {
            let duration = now.timeIntervalSince(lastTime)
            addDuration(duration, for: previousPosture)
        }
        
        // Check for closed→open transition (a "fold" cycle)
        if lastPosture == .closed && (state.posture == .partiallyOpen || state.posture == .fullyOpen) {
            stats.foldCount += 1
        }
        
        lastPosture = state.posture
        lastTransitionTime = now
    }
    
    /// Get current statistics
    public func getStats() -> Stats {
        var currentStats = stats
        
        // Add current state's ongoing duration
        if isTracking, let lastTime = lastTransitionTime, let posture = lastPosture {
            let duration = Date.now.timeIntervalSince(lastTime)
            switch posture {
            case .closed:
                currentStats.closedDuration += duration
            case .fullyOpen:
                currentStats.openDuration += duration
            case .partiallyOpen:
                currentStats.partialDuration += duration
            case .noHinge, .unknown:
                break
            }
        }
        
        currentStats.updatedAt = .now
        return currentStats
    }
    
    /// Reset all statistics
    public func reset() {
        stats = Stats()
        lastPosture = nil
        lastTransitionTime = nil
        if isTracking {
            lastTransitionTime = .now
        }
    }
    
    private func addDuration(_ duration: TimeInterval, for posture: FoldPosture) {
        switch posture {
        case .closed:
            stats.closedDuration += duration
        case .fullyOpen:
            stats.openDuration += duration
        case .partiallyOpen:
            stats.partialDuration += duration
        case .noHinge, .unknown:
            break
        }
    }
}
