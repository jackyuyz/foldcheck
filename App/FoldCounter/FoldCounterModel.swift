import Foundation
import Observation
import FoldKit
import TestsKit

/// F5: "Folds observed by FoldCheck". Two counters fed the same states: one for this launch,
/// one continuing the all-time totals saved in UserDefaults. Both only run while the app is
/// in the foreground; iOS has no background hinge events and no lifetime fold count.
@MainActor
@Observable
final class FoldCounterModel {
    static let storageKey = "foldcheck.foldCounter.allTime"

    private(set) var session: FoldCounter
    private(set) var allTime: FoldCounter
    private(set) var latestState: FoldState = .noHinge
    private let defaults: UserDefaults
    /// Fold count at the last save, so a new fold is saved right away.
    private var savedFoldCount: Int

    init(defaults: UserDefaults = .standard, now: Date = .now) {
        self.defaults = defaults
        #if DEBUG
        if ProcessInfo.processInfo.arguments.contains("-ResetFoldCounter") {
            defaults.removeObject(forKey: Self.storageKey)
        }
        #endif
        let saved = defaults.data(forKey: Self.storageKey)
            .flatMap { try? JSONDecoder().decode(FoldCounter.Stats.self, from: $0) }
        session = FoldCounter(stats: .init(startedAt: now, updatedAt: now))
        allTime = FoldCounter(stats: saved ?? .init(startedAt: now, updatedAt: now))
        savedFoldCount = saved?.foldCount ?? 0
    }

    var isTracking: Bool { session.isTracking }

    /// App became active: start counting from the current posture.
    func enterForeground(current: FoldState, at time: Date = .now) {
        session.startTracking(at: time)
        allTime.startTracking(at: time)
        process(current, at: time)
    }

    /// App left the foreground: stop counting and save.
    func leaveForeground(at time: Date = .now) {
        session.stopTracking(at: time)
        allTime.stopTracking(at: time)
        save(at: time)
    }

    func process(_ state: FoldState, at time: Date = .now) {
        latestState = state
        session.process(state, at: time)
        allTime.process(state, at: time)
        if allTime.stats(at: time).foldCount != savedFoldCount {
            save(at: time)
        }
    }

    /// Called about once a second: saves a fold whose debounce ran out with no further events.
    func tick(at time: Date = .now) {
        if allTime.stats(at: time).foldCount != savedFoldCount {
            save(at: time)
        }
    }

    func sessionStats(at time: Date = .now) -> FoldCounter.Stats {
        session.stats(at: time)
    }

    func allTimeStats(at time: Date = .now) -> FoldCounter.Stats {
        allTime.stats(at: time)
    }

    func reset(at time: Date = .now) {
        session.reset(at: time)
        allTime.reset(at: time)
        save(at: time)
    }

    private func save(at time: Date) {
        let stats = allTime.stats(at: time)
        guard let data = try? JSONEncoder().encode(stats) else { return }
        defaults.set(data, forKey: Self.storageKey)
        savedFoldCount = stats.foldCount
    }
}
