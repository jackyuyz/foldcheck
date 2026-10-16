#if canImport(SwiftData)
import Testing
import Foundation
import SwiftData
import TestsKit
@testable import Library

@Suite("Session library")
@MainActor
struct SessionLibraryTests {
    let container: ModelContainer
    let library: SessionLibrary
    let t0 = Date(timeIntervalSinceReferenceDate: 4_000_000)

    init() throws {
        let configuration = ModelConfiguration(isStoredInMemoryOnly: true, cloudKitDatabase: .none)
        container = try ModelContainer(for: StoredSession.self, configurations: configuration)
        library = SessionLibrary(context: container.mainContext)
    }

    func session(startedAt offset: TimeInterval, _ results: [(TestID, TestOutcome)]) -> InspectionSession {
        InspectionSession(
            startedAt: t0.addingTimeInterval(offset),
            deviceModel: "iPhone Duo",
            osVersion: "27.1",
            hasHinge: true,
            results: results.map { TestResult(id: $0.0, outcome: $0.1, finishedAt: t0.addingTimeInterval(offset + 1)) },
            completedAt: t0.addingTimeInterval(offset + 60)
        )
    }

    @Test("A saved session round-trips unchanged, with summary fields copied")
    func roundTrip() throws {
        var original = session(startedAt: 0, [(.pixels, .pass), (.hingeSweep, .attention)])
        original.results[1].series = [TestSeriesPoint(t: 0.5, value: 92, segment: 1)]

        let record = try library.save(original, isFullInspection: true)

        #expect(record.session == original)
        #expect(record.overallStatus == .attention)
        #expect(record.overallScore == original.overallScore)
        #expect(try library.sessions() == [original])
    }

    @Test("Saving the same session twice updates it instead of duplicating")
    func noDoubleSave() throws {
        var original = session(startedAt: 0, [(.pixels, .pass)])
        try library.save(original, isFullInspection: true)
        original.setResult(TestResult(id: .pixels, outcome: .fail))
        try library.save(original, isFullInspection: false)

        let records = try container.mainContext.fetch(StoredSession.newestFirst)
        #expect(records.count == 1)
        #expect(records.first?.overallStatus == .fail)
        // A later manual save of a quick-test copy doesn't demote a full inspection.
        #expect(records.first?.isFullInspection == true)
    }

    @Test("Sessions come back newest first and delete removes them")
    func orderAndDelete() throws {
        let older = session(startedAt: 0, [(.pixels, .pass)])
        let newer = session(startedAt: 100, [(.cameras, .pass)])
        try library.save(older, isFullInspection: false)
        try library.save(newer, isFullInspection: false)

        #expect(try library.sessions().map(\.id) == [newer.id, older.id])

        try library.delete([try #require(try library.stored(id: newer.id))])
        #expect(try library.sessions().map(\.id) == [older.id])
        #expect(try library.stored(id: newer.id) == nil)
    }

    @Test("Latest full inspection ignores newer quick tests")
    func latestFull() throws {
        let full = session(startedAt: 0, [(.pixels, .pass), (.cameras, .pass)])
        let quick = session(startedAt: 100, [(.pixels, .fail)])
        try library.save(full, isFullInspection: true)
        try library.save(quick, isFullInspection: false)

        #expect(try library.latestFullInspection()?.id == full.id)
    }

    @Test("Latest result per test spans full inspections and quick tests")
    func latestResults() throws {
        let full = session(startedAt: 0, [(.pixels, .pass), (.hingeSweep, .pass)])
        let quick = session(startedAt: 100, [(.pixels, .fail), (.hingeSweep, .skipped)])
        try library.save(full, isFullInspection: true)
        try library.save(quick, isFullInspection: false)

        let latest = try library.latestResults()
        #expect(latest[.pixels]?.result.outcome == .fail)
        #expect(latest[.pixels]?.sessionID == quick.id)
        #expect(latest[.hingeSweep]?.result.outcome == .pass)
        #expect(latest[.audio] == nil)
    }

    @Test("Empty library")
    func empty() throws {
        #expect(try library.sessions().isEmpty)
        #expect(try library.latestFullInspection() == nil)
        #expect(try library.latestResults().isEmpty)
    }
}
#endif
