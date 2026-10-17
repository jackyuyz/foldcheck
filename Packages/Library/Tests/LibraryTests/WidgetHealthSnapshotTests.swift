import Foundation
import Testing
import TestsKit
@testable import Library

@Suite("Widget health snapshot")
struct WidgetHealthSnapshotTests {
    private func snapshot(_ outcome: TestOutcome?, language: String = "zh-Hans") -> WidgetHealthSnapshot {
        let sessions = outcome.map { value in
            [InspectionSession(deviceModel: "Private model", osVersion: "27.1", hasHinge: true,
                results: [TestResult(id: .pixels, outcome: value, notes: "PRIVATE NOTE")])]
        } ?? []
        return WidgetHealthSnapshot(health: DeviceHealth(sessions: sessions, context: .mock(hasHinge: true)), languageCode: language)
    }

    private func directory() throws -> URL {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent("foldcheck-widget-\(UUID())")
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: false)
        return directory
    }

    @Test("Shared snapshot contains only aggregates, not inspection content")
    func minimalSnapshot() throws {
        let value = snapshot(.attention)
        #expect(value.score == 70 && value.attentionCount == 1 && value.measuredCount == 1)
        #expect(value.totalCount == 9)
        let data = try JSONEncoder().encode(value)
        let json = String(decoding: data, as: UTF8.self)
        #expect(!json.contains("PRIVATE NOTE") && !json.contains("Private model"))
        #expect(try JSONDecoder().decode(WidgetHealthSnapshot.self, from: data) == value)
    }

    @Test("Only changed snapshots write; an empty replacement clears stale results")
    func changesAndDeletion() throws {
        let store = WidgetHealthSnapshotStore(directory: try directory())
        #expect(store.read() == nil)
        let measured = snapshot(.pass)
        #expect(try store.write(measured) == true)
        #expect(try store.write(measured) == false)
        #expect(store.read() == measured)
        let empty = snapshot(nil, language: "ja")
        #expect(try store.write(empty) == true)
        #expect(store.read()?.score == nil)
        #expect(store.read()?.languageCode == "ja")
    }

    @Test("Missing App Group and corrupt or future snapshots fall back safely")
    func unavailable() throws {
        let unavailable = WidgetHealthSnapshotStore(directory: nil)
        #expect(unavailable.read() == nil)
        #expect(try unavailable.write(snapshot(.pass)) == false)
        let directory = try directory()
        let store = WidgetHealthSnapshotStore(directory: directory)
        let file = directory.appendingPathComponent("widget-health-v1.json")
        try Data("broken".utf8).write(to: file)
        #expect(store.read() == nil)
        var object = try #require(try JSONSerialization.jsonObject(with: JSONEncoder().encode(snapshot(.pass))) as? [String: Any])
        object["version"] = 2
        try JSONSerialization.data(withJSONObject: object).write(to: file)
        #expect(store.read() == nil)
    }

    @Test("Widget links select Home and leave verification URLs separate")
    func links() throws {
        #expect(HealthWidget.opensHome(HealthWidget.homeURL))
        #expect(!HealthWidget.opensHome(try #require(URL(string: "foldcheck://verify?report=example"))))
        #expect(!HealthWidget.opensHome(try #require(URL(string: "https://home"))))
    }
}
