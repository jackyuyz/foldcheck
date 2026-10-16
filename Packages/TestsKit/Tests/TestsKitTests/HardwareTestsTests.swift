import Testing
import Foundation
@testable import TestsKit

@Suite("Cameras (T5)")
struct CameraTestTests {
    let back = CameraInfo(id: "back", name: "Back Camera", position: .back)
    let front = CameraInfo(id: "front", name: "Front Camera", position: .front)
    let stats = FrameStats(meanLuma: 0.4, sharpness: 0.05)

    @Test("Flat frames have no sharpness; edges do")
    func frameAnalysis() throws {
        let flat = try #require(FrameAnalysis.stats(gray: Array(repeating: 128, count: 16), width: 4, height: 4))
        #expect(abs(flat.meanLuma - 128.0 / 255) < 0.001)
        #expect(flat.sharpness == 0)

        let checker = (0..<64).map { i -> UInt8 in ((i % 8) + (i / 8)) % 2 == 0 ? 0 : 255 }
        let sharp = try #require(FrameAnalysis.stats(gray: checker, width: 8, height: 8))
        #expect(sharp.sharpness > 0.9)
        #expect(FrameAnalysis.stats(gray: [1, 2], width: 1, height: 2) == nil)
    }

    @Test("Outcome rules")
    func outcomes() {
        #expect(CameraTestSession.outcome(cameraCount: 0, checks: []) == .unavailable)
        #expect(CameraTestSession.outcome(cameraCount: 2, checks: [.looksRight(stats), .looksRight(stats)]) == .pass)
        #expect(CameraTestSession.outcome(cameraCount: 2, checks: [.looksRight(stats), .looksWrong(stats)]) == .attention)
        #expect(CameraTestSession.outcome(cameraCount: 2, checks: [.looksWrong(stats), .noFrame]) == .fail)
        #expect(CameraTestSession.outcome(cameraCount: 2, checks: [.looksRight(stats), .notAvailableNow]) == .pass)
        #expect(CameraTestSession.outcome(cameraCount: 1, checks: [.notAvailableNow]) == .notApplicable)
    }

    @Test("Steps through cameras and stores per-camera metrics")
    func session() {
        var session = CameraTestSession(cameras: [back, front])
        #expect(session.currentCamera == back)
        session.record(.looksRight(stats), for: back)
        #expect(session.currentCamera == front)
        session.record(.notAvailableNow, for: front)
        #expect(session.isFinished)

        let result = session.result()
        #expect(result.id == .cameras)
        #expect(result.outcome == .pass)
        #expect(result.metrics[TestMetricKey.camerasAvailable] == 2)
        #expect(result.metrics[TestMetricKey.camerasTested] == 1)
        #expect(result.metrics[TestMetricKey.cameraOK(0)] == 1)
        #expect(result.metrics[TestMetricKey.cameraBrightness(0)] == 0.4)
        #expect(result.metrics[TestMetricKey.cameraOK(1)] == nil)
    }
}

@Suite("Audio (T6)")
struct AudioTestTests {
    @Test("Tone WAV has a valid header and sound in one channel only")
    func tone() {
        let wav = ToneGenerator.wav(channel: .right, duration: 0.1, sampleRate: 8_000)
        #expect(String(decoding: wav.prefix(4), as: UTF8.self) == "RIFF")
        #expect(String(decoding: wav[8..<16], as: UTF8.self) == "WAVEfmt ")
        let frames = 800
        #expect(wav.count == 44 + frames * 4)

        let samples: [Int16] = wav.dropFirst(44).withUnsafeBytes { raw in
            (0..<(frames * 2)).map { Int16(littleEndian: raw.loadUnaligned(fromByteOffset: $0 * 2, as: Int16.self)) }
        }
        let left = stride(from: 0, to: samples.count, by: 2).map { samples[$0] }
        let right = stride(from: 1, to: samples.count, by: 2).map { samples[$0] }
        #expect(left.allSatisfy { $0 == 0 })
        #expect(right.contains { abs(Int($0)) > 10_000 })
        #expect(right.first == 0)
    }

    @Test("Outcome rules")
    func outcomes() {
        var session = AudioTestSession()
        session.leftHeard = true
        session.rightHeard = true
        session.micPeakDB = -20
        session.playbackHeard = true
        #expect(session.outcome == .pass)

        session.micPeakDB = -60
        #expect(session.outcome == .attention)

        session.micPeakDB = -20
        session.rightHeard = false
        #expect(session.outcome == .attention)

        session.hardwareError = true
        #expect(session.outcome == .fail)

        #expect(AudioTestSession().outcome == .attention)
    }

    @Test("Metrics only for steps that ran")
    func metrics() {
        var session = AudioTestSession()
        session.leftHeard = true
        session.rightHeard = false
        let metrics = session.result().metrics
        #expect(metrics[TestMetricKey.speakerLeftConfirmed] == 1)
        #expect(metrics[TestMetricKey.speakerRightConfirmed] == 0)
        #expect(metrics[TestMetricKey.micPeakLevel] == nil)
    }
}

@Suite("Touch ID (T7)")
struct BiometricCheckTests {
    @Test("Outcome rules", arguments: [
        (BiometricCheck.matched, TestOutcome.pass),
        (.notEnrolled, .attention),
        (.lockedOut, .attention),
        (.notMatched, .fail),
        (.unavailable, .unavailable),
    ])
    func outcomes(check: BiometricCheck, expected: TestOutcome) {
        #expect(check.outcome == expected)
        #expect(check.result().id == .touchID)
    }

    @Test("Touch ID applies only to Touch ID devices")
    func applicability() {
        #expect(TestID.touchID.isApplicable(DeviceContext(biometricType: "touchID")))
        #expect(!TestID.touchID.isApplicable(DeviceContext(biometricType: "faceID")))
        #expect(!TestID.touchID.isApplicable(DeviceContext(biometricType: nil)))
        #expect(TestID.cameras.isApplicable(DeviceContext(biometricType: nil)))
    }
}

@Suite("Sensors and haptics (T8)")
struct SensorsTestTests {
    @Test("Accelerometer reads about 1 g")
    func accelerometer() {
        let resting = Array(repeating: Vector3(x: 0, y: -0.98, z: 0.1), count: 10)
        #expect(SensorsTestSession.accelerometerResult(samples: resting) == .ok)
        let dead = Array(repeating: Vector3(x: 0, y: 0, z: 0), count: 10)
        #expect(SensorsTestSession.accelerometerResult(samples: dead) == .faulty)
        #expect(SensorsTestSession.accelerometerResult(samples: []) == .faulty)
    }

    @Test("Gyroscope needs a visible turn")
    func gyroscope() {
        #expect(SensorsTestSession.gyroscopeResult(samples: [Vector3(x: 0, y: 0, z: 0), Vector3(x: 1.2, y: 0, z: 0)]) == .ok)
        #expect(SensorsTestSession.gyroscopeResult(samples: [Vector3(x: 0.01, y: 0, z: 0)]) == .notConfirmed)
        #expect(SensorsTestSession.gyroscopeResult(samples: []) == .faulty)
    }

    @Test("Outcome rules")
    func outcomes() {
        var session = SensorsTestSession()
        #expect(session.outcome == .unavailable)
        for part in SensorPart.allCases { session.record(.unavailable, for: part) }
        #expect(session.outcome == .unavailable)

        session.record(.ok, for: .accelerometer)
        session.record(.ok, for: .haptics)
        #expect(session.outcome == .pass)
        #expect(session.result().metrics[TestMetricKey.sensorOK(.proximity)] == nil)

        session.record(.notConfirmed, for: .proximity)
        #expect(session.outcome == .attention)

        session.record(.faulty, for: .gyroscope)
        #expect(session.outcome == .fail)
        #expect(session.result().metrics[TestMetricKey.sensorOK(.gyroscope)] == 0)
    }
}

@Suite("Buttons (T9)")
struct ButtonsTestTests {
    @Test("Volume direction ignores tiny changes")
    func direction() {
        #expect(ButtonsTestSession.direction(from: 0.5, to: 0.5625) == .up)
        #expect(ButtonsTestSession.direction(from: 0.5, to: 0.4375) == .down)
        #expect(ButtonsTestSession.direction(from: 0.5, to: 0.505) == nil)
    }

    @Test("Ask for the button that can change the volume first")
    func order() {
        #expect(ButtonsTestSession.order(startingVolume: 1.0) == [.down, .up])
        #expect(ButtonsTestSession.order(startingVolume: 0.5) == [.down, .up])
        #expect(ButtonsTestSession.order(startingVolume: 0) == [.up, .down])
    }

    @Test("Outcome rules")
    func outcomes() {
        var session = ButtonsTestSession()
        session.record(true, for: .up)
        session.record(true, for: .down)
        session.checklist = [.side: .works, .action: .works, .cameraControl: .notOnThisPhone]
        #expect(session.outcome == .pass)
        #expect(session.result().metrics[TestMetricKey.buttonWorks(.cameraControl)] == nil)
        #expect(session.result().metrics[TestMetricKey.buttonWorks(.side)] == 1)

        session.checklist[.action] = .doesNotWork
        #expect(session.outcome == .attention)

        session.checklist[.action] = .works
        session.record(false, for: .up)
        #expect(session.outcome == .attention)
    }
}
