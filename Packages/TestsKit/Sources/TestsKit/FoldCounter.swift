import Foundation
import FoldKit

/// Counts fold cycles (closed→open) and time per display, only while tracking is on.
///
/// Important: tracking is on only while FoldCheck is in the foreground. iOS provides no
/// background hinge events and no lifetime fold count, so this is "folds observed by
/// FoldCheck", never the device's lifetime count.
///
/// Debounce: a posture change only counts once it has lasted `debounce` seconds, so a
/// hinge flapping across the closed/open boundary (or a transient `unknown`) isn't a fold.
public struct FoldCounter: Sendable, Equatable {
    /// How long a new posture must last before it is accepted.
    public static let debounce: TimeInterval = 0.3

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
    public private(set) var isTracking = false
    /// The accepted posture and since when it has been counted.
    private var committed: FoldPosture?
    private var committedAt: Date?
    /// A posture change waiting out the debounce.
    private var pending: FoldPosture?
    private var pendingSince: Date?

    /// - Parameter stats: Totals to continue from (e.g. the persisted all-time totals).
    public init(stats: Stats = Stats()) {
        self.stats = stats
    }

    /// Start tracking (app entered the foreground). The first state after this sets the
    /// posture without counting: whatever happened while backgrounded wasn't observed.
    public mutating func startTracking(at time: Date = .now) {
        guard !isTracking else { return }
        isTracking = true
        committed = nil
        committedAt = nil
        pending = nil
        pendingSince = nil
    }

    /// Stop tracking (app left the foreground). Time up to now is kept; a change still
    /// inside its debounce is dropped.
    public mutating func stopTracking(at time: Date = .now) {
        guard isTracking else { return }
        settle(at: time)
        accumulate(until: time)
        isTracking = false
        committed = nil
        committedAt = nil
        pending = nil
        pendingSince = nil
    }

    /// Process a new fold state observed at `time` (defaults to the state's timestamp).
    public mutating func process(_ state: FoldState, at time: Date? = nil) {
        guard isTracking else { return }
        let now = time ?? state.timestamp
        settle(at: now)
        stats.updatedAt = now

        let posture = state.posture
        // No hinge or a transient unknown reading: keep the current posture.
        guard posture == .closed || posture == .partiallyOpen || posture == .fullyOpen else { return }

        guard let current = committed else {
            commit(posture, at: now)
            return
        }
        if posture == current {
            // Flapped back before the debounce ran out: nothing happened.
            pending = nil
            pendingSince = nil
        } else if let waiting = pending, Self.side(waiting) == Self.side(posture) {
            // Still on the same side of the fold (e.g. partially → fully open): keep the timer.
            pending = posture
        } else {
            pending = posture
            pendingSince = now
        }
    }

    /// Statistics as of `time`, including the current posture's ongoing time and any change
    /// whose debounce has run out.
    public func stats(at time: Date = .now) -> Stats {
        var copy = self
        if copy.isTracking {
            copy.settle(at: time)
            copy.accumulate(until: time)
        }
        copy.stats.updatedAt = max(copy.stats.updatedAt, time)
        return copy.stats
    }

    /// Kept for existing callers.
    public func getStats() -> Stats {
        stats(at: .now)
    }

    /// Reset all statistics (tracking state is kept).
    public mutating func reset(at time: Date = .now) {
        // Accept a change that already outlasted its debounce, so it isn't counted after the reset.
        if isTracking { settle(at: time) }
        stats = Stats(startedAt: time, updatedAt: time)
        if isTracking, committed != nil {
            committedAt = time
        }
    }

    // MARK: Internals

    private static func side(_ posture: FoldPosture) -> Bool {
        posture == .closed
    }

    /// Accepts the pending posture if it has lasted the debounce by `time`.
    private mutating func settle(at time: Date) {
        guard let waiting = pending, let since = pendingSince, time.timeIntervalSince(since) >= Self.debounce else { return }
        commit(waiting, at: since)
    }

    private mutating func commit(_ posture: FoldPosture, at time: Date) {
        accumulate(until: time)
        if committed == .closed && posture != .closed {
            stats.foldCount += 1
        }
        committed = posture
        committedAt = time
        pending = nil
        pendingSince = nil
    }

    /// Adds the committed posture's time up to `time`.
    private mutating func accumulate(until time: Date) {
        guard let posture = committed, let since = committedAt, time > since else { return }
        let duration = time.timeIntervalSince(since)
        switch posture {
        case .closed: stats.closedDuration += duration
        case .fullyOpen: stats.openDuration += duration
        case .partiallyOpen: stats.partialDuration += duration
        case .noHinge, .unknown: break
        }
        committedAt = time
    }
}
