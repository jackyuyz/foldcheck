#if canImport(SwiftData)
import Foundation
import SwiftData
import TestsKit

/// Saves, deletes and reads inspection sessions in a SwiftData `ModelContext`.
/// Everything stays on the device: the app's container has no CloudKit database.
public struct SessionLibrary {
    public let context: ModelContext

    public init(context: ModelContext) {
        self.context = context
    }

    /// Saves `session`, or updates the stored copy when the same session was saved before,
    /// so saving twice (auto-save, then the button) never makes a duplicate.
    @discardableResult
    public func save(_ session: InspectionSession, isFullInspection: Bool) throws -> StoredSession {
        if let existing = try stored(id: session.id) {
            try existing.update(from: session, isFullInspection: existing.isFullInspection || isFullInspection)
            try context.save()
            return existing
        }
        let record = try StoredSession(session, isFullInspection: isFullInspection)
        context.insert(record)
        try context.save()
        return record
    }

    public func stored(id: UUID) throws -> StoredSession? {
        try context.fetch(StoredSession.withID(id)).first
    }

    public func delete(_ records: [StoredSession]) throws {
        for record in records {
            context.delete(record)
        }
        try context.save()
    }

    /// All saved sessions that still decode, newest first.
    public func sessions() throws -> [InspectionSession] {
        try context.fetch(StoredSession.newestFirst).compactMap(\.session)
    }

    public func latestFullInspection() throws -> InspectionSession? {
        try context.fetch(StoredSession.latestFullInspection).first?.session
    }

    /// Latest result per test across every saved session (see `InspectionSession.latestResults`).
    public func latestResults(includeUnmeasured: Bool = false) throws -> [TestID: LatestTestResult] {
        InspectionSession.latestResults(in: try sessions(), includeUnmeasured: includeUnmeasured)
    }
}
#endif
