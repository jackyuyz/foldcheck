import Testing
import Foundation
@testable import TestsKit

@Suite("Health dashboard (design A)")
struct DeviceHealthTests {
    private let duo = DeviceContext(foldState: FoldState(posture: .fullyOpen, angleDegrees: 180), biometricType: "touchID")
    private let faceIDPhone = DeviceContext(foldState: .noHinge, biometricType: "faceID")

    private func session(daysAgo: Double, _ results: [(TestID, TestOutcome)]) -> InspectionSession {
        let start = Date(timeIntervalSinceNow: -daysAgo * 86_400)
        var session = InspectionSession(startedAt: start, deviceModel: "iPhone Duo", osVersion: "iOS 27.1", hasHinge: true)
        for (id, outcome) in results {
            session.setResult(TestResult(id: id, outcome: outcome, finishedAt: start.addingTimeInterval(60)))
        }
        return session
    }

    @Test("Parts follow the device")
    func components() {
        #expect(DeviceHealth(sessions: [], context: duo).items.map(\.component) == HealthComponent.allCases)
        let phone = DeviceHealth(sessions: [], context: faceIDPhone).items.map(\.component)
        #expect(!phone.contains(.hinge) && !phone.contains(.crease) && !phone.contains(.touchID))
        #expect(phone.contains(.touch) && phone.contains(.screen))
    }

    @Test("No saved inspections: nothing measured, no score")
    func empty() {
        let health = DeviceHealth(sessions: [], context: duo)
        #expect(!health.hasData)
        #expect(health.score == nil && health.status == nil && health.lastCheckedAt == nil)
        #expect(health.notMeasured.count == health.items.count)
    }

    @Test("Latest measurement wins; a later skip doesn't hide it")
    func latest() throws {
        let health = DeviceHealth(sessions: [
            session(daysAgo: 30, [(.hingeSweep, .pass), (.pixels, .attention)]),
            session(daysAgo: 1, [(.hingeSweep, .attention), (.pixels, .skipped)]),
        ], context: duo)
        let hinge = try #require(health.items.first { $0.component == .hinge })
        #expect(hinge.outcome == .attention)
        let screen = try #require(health.items.first { $0.component == .screen })
        #expect(screen.outcome == .attention)
        #expect(health.status == .attention)
        #expect(health.score == 70)
        #expect(health.needsAttention.map(\.component) == [.hinge, .screen])
    }

    @Test("Touch shows the worse of the outer and inner grids")
    func touch() throws {
        let health = DeviceHealth(sessions: [
            session(daysAgo: 1, [(.touchGridOuter, .pass), (.touchGridInner, .fail)]),
        ], context: duo)
        let touch = try #require(health.items.first { $0.component == .touch })
        #expect(touch.outcome == .fail)
        #expect(touch.result?.id == .touchGridInner)
        #expect(health.status == .fail)
        #expect(health.score == 0)  // one part (touch), scored by its worse grid
    }
}
