#if canImport(SwiftData)
import Foundation
import SwiftData
import TestsKit

/// A saved inspection.
///
/// `InspectionSession` (TestsKit) stays the source of truth: it is stored JSON-encoded in
/// `payload`, so changes to the package types don't need a SwiftData migration. The other
/// fields are copies kept only for sorting and filtering in queries.
@Model
public final class StoredSession {
    @Attribute(.unique) public private(set) var sessionID: UUID
    public private(set) var startedAt: Date
    public private(set) var completedAt: Date?
    public private(set) var savedAt: Date
    /// True when the session ran every test (Home's "last inspection"); false for quick tests.
    public private(set) var isFullInspection: Bool
    /// `TestOutcome.rawValue` of the session's overall status.
    public private(set) var overallStatusRaw: String
    public private(set) var overallScore: Int?
    public private(set) var payload: Data

    public init(_ session: InspectionSession, isFullInspection: Bool, savedAt: Date = .now) throws {
        sessionID = session.id
        startedAt = session.startedAt
        completedAt = session.completedAt
        self.savedAt = savedAt
        self.isFullInspection = isFullInspection
        overallStatusRaw = session.overallStatus.rawValue
        overallScore = session.overallScore
        payload = try JSONEncoder().encode(session)
    }

    /// Replaces the stored copy with `session` (same id).
    func update(from session: InspectionSession, isFullInspection: Bool) throws {
        payload = try JSONEncoder().encode(session)
        startedAt = session.startedAt
        completedAt = session.completedAt
        self.isFullInspection = isFullInspection
        overallStatusRaw = session.overallStatus.rawValue
        overallScore = session.overallScore
    }

    /// The decoded session, or nil if the payload no longer decodes.
    public var session: InspectionSession? {
        try? JSONDecoder().decode(InspectionSession.self, from: payload)
    }

    public var overallStatus: TestOutcome {
        TestOutcome(rawValue: overallStatusRaw) ?? .skipped
    }
}

public extension StoredSession {
    /// All saved sessions, newest first.
    static var newestFirst: FetchDescriptor<StoredSession> {
        FetchDescriptor(sortBy: [SortDescriptor(\.startedAt, order: .reverse)])
    }

    /// The most recent saved full inspection.
    static var latestFullInspection: FetchDescriptor<StoredSession> {
        var descriptor = FetchDescriptor<StoredSession>(
            predicate: #Predicate { $0.isFullInspection },
            sortBy: [SortDescriptor(\.startedAt, order: .reverse)]
        )
        descriptor.fetchLimit = 1
        return descriptor
    }

    /// The saved copy of the session with `id`, if any.
    static func withID(_ id: UUID) -> FetchDescriptor<StoredSession> {
        var descriptor = FetchDescriptor<StoredSession>(predicate: #Predicate { $0.sessionID == id })
        descriptor.fetchLimit = 1
        return descriptor
    }
}
#endif
