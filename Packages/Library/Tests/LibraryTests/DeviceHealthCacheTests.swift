import Foundation
import Testing
import TestsKit
@testable import Library

@Suite("Cached dashboard")
struct DeviceHealthCacheTests {
    private func payload(_ outcome: TestOutcome, id: UUID = UUID()) throws -> Data {
        let session = InspectionSession(
            id: id, deviceModel: "iPhone Duo", osVersion: "27.1", hasHinge: true,
            results: [TestResult(id: .pixels, outcome: outcome)]
        )
        return try JSONEncoder().encode(session)
    }

    @Test("Angle and posture updates reuse the cached dashboard")
    func hingeUpdates() throws {
        var cache = DeviceHealthCache()
        let records = [try payload(.pass)]
        #expect(cache.update(payloads: records, context: .mock(hasHinge: true)) == true)
        for angle in 0...180 {
            var context = DeviceContext.mock(hasHinge: true)
            context.foldState = FoldState(posture: angle == 0 ? .closed : .partiallyOpen, angleDegrees: Double(angle))
            #expect(cache.update(payloads: records, context: context) == false)
        }
        #expect(cache.health?.score == 100)
    }

    @Test("Insert, in-place update, and deletion invalidate saved results")
    func recordChanges() throws {
        var cache = DeviceHealthCache()
        let context = DeviceContext.mock(hasHinge: true)
        #expect(cache.update(payloads: [], context: context) == true)
        #expect(cache.health?.hasData == false)
        let id = UUID()
        let passing = try payload(.pass, id: id)
        #expect(cache.update(payloads: [passing], context: context) == true)
        #expect(cache.health?.score == 100)
        #expect(cache.update(payloads: [passing], context: context) == false)
        let failing = try payload(.fail, id: id)
        #expect(cache.update(payloads: [failing], context: context) == true)
        #expect(cache.health?.status == .fail)
        #expect(cache.update(payloads: [], context: context) == true)
        #expect(cache.health?.score == nil)
    }

    @Test("Device applicability changes refresh parts without new records")
    func applicability() throws {
        var cache = DeviceHealthCache()
        let records = [try payload(.attention)]
        #expect(cache.update(payloads: records, context: .mock(hasHinge: true)) == true)
        #expect(cache.health?.items.count == 9)
        var phone = DeviceContext.mock(hasHinge: false)
        phone.biometricType = "faceID"
        #expect(cache.update(payloads: records, context: phone) == true)
        #expect(cache.health?.items.count == 6)
        #expect(cache.health?.score == 70)
        #expect(cache.update(payloads: records, context: phone) == false)
    }
}
