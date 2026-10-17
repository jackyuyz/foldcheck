import Foundation
import TestsKit

/// Only this small aggregate is shared with the widget. Notes, photos, individual results,
/// hardware samples, reports and signing keys remain in the app's private container.
public struct WidgetHealthSnapshot: Codable, Equatable, Sendable {
    public let version: Int
    public let score: Int?
    public let status: TestOutcome?
    public let measuredCount: Int
    public let totalCount: Int
    public let attentionCount: Int
    public let lastCheckedAt: Date?
    public let languageCode: String

    public init(health: DeviceHealth, languageCode: String) {
        version = 1
        score = health.score
        status = health.status
        measuredCount = health.measured.count
        totalCount = health.items.count
        attentionCount = health.needsAttention.count
        lastCheckedAt = health.lastCheckedAt
        self.languageCode = languageCode
    }
}

public enum HealthWidget {
    public static let kind = "FoldCheckHealth"
    public static let appGroup = "group.com.jackyu.foldcheck"
    public static let homeURL = URL(string: "foldcheck://home")!

    public static func opensHome(_ url: URL) -> Bool {
        url.scheme == "foldcheck" && url.host == "home" && (url.path.isEmpty || url.path == "/")
    }
}

/// A versioned, atomic file in the existing App Group; the SwiftData store stays private.
public struct WidgetHealthSnapshotStore: Sendable {
    private let fileURL: URL?

    public init(directory: URL?) {
        fileURL = directory?.appendingPathComponent("widget-health-v1.json")
    }

    public static var shared: Self {
        Self(directory: FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: HealthWidget.appGroup))
    }

    public func read() -> WidgetHealthSnapshot? {
        guard let fileURL, let data = try? Data(contentsOf: fileURL),
              let snapshot = try? JSONDecoder().decode(WidgetHealthSnapshot.self, from: data),
              snapshot.version == 1 else { return nil }
        return snapshot
    }

    /// Returns true only for a changed write. Missing App Groups or unchanged data return
    /// false; write errors throw and leave the previous atomic file intact.
    @discardableResult
    public func write(_ snapshot: WidgetHealthSnapshot) throws -> Bool {
        guard let fileURL, read() != snapshot else { return false }
        let data = try JSONEncoder().encode(snapshot)
        #if os(iOS)
        try data.write(to: fileURL, options: [.atomic, .completeFileProtectionUntilFirstUserAuthentication])
        #else
        try data.write(to: fileURL, options: .atomic)
        #endif
        return true
    }
}
