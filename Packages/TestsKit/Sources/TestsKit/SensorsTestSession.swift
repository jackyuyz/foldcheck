import Foundation

/// A 3-axis reading: acceleration in g (gravity included) or rotation rate in rad/s.
public struct Vector3: Codable, Sendable, Equatable {
    public var x: Double
    public var y: Double
    public var z: Double

    public init(x: Double, y: Double, z: Double) {
        self.x = x
        self.y = y
        self.z = z
    }

    public var magnitude: Double { (x * x + y * y + z * z).squareRoot() }
}

/// The parts checked by the sensors and haptics test (T8), in order.
public enum SensorPart: String, Codable, Sendable, CaseIterable, Equatable {
    case accelerometer, gyroscope, proximity, haptics
}

/// How one part did.
public enum SensorPartResult: String, Codable, Sendable, Equatable {
    /// Readings looked right, or the user confirmed it.
    case ok
    /// It ran but the user didn't confirm it (didn't feel the taps, didn't cover the sensor).
    case notConfirmed
    /// It's present but the readings are missing or implausible.
    case faulty
    /// The device or the system doesn't offer it (e.g. the simulator has no motion sensors).
    case unavailable
}

/// Results of one sensors and haptics run (T8).
public struct SensorsTestSession: Sendable, Equatable {
    /// At rest the accelerometer reads gravity, 1 g. Outside this range the readings are wrong.
    public static let plausibleGravity: ClosedRange<Double> = 0.7...1.3
    /// Turning the phone by hand easily passes this rotation rate (rad/s).
    public static let rotationSeen = 0.5

    public private(set) var parts: [SensorPart: SensorPartResult] = [:]

    public init() {}

    public mutating func record(_ result: SensorPartResult, for part: SensorPart) {
        parts[part] = result
    }

    /// Plausible when the median magnitude is about 1 g. No samples from an available sensor
    /// is faulty.
    public static func accelerometerResult(samples: [Vector3]) -> SensorPartResult {
        let magnitudes = samples.map(\.magnitude).sorted()
        guard !magnitudes.isEmpty else { return .faulty }
        let median = magnitudes[magnitudes.count / 2]
        return plausibleGravity.contains(median) ? .ok : .faulty
    }

    /// OK once the user's turn shows up as rotation. Readings that never move are only
    /// "not confirmed": the user may simply not have turned the phone.
    public static func gyroscopeResult(samples: [Vector3]) -> SensorPartResult {
        guard let peak = samples.map(\.magnitude).max() else { return .faulty }
        return peak >= rotationSeen ? .ok : .notConfirmed
    }

    /// All parts unavailable is Unavailable; any faulty part is Fail; any part the user didn't
    /// confirm is Attention; otherwise Pass. Parts that aren't available are left out.
    public var outcome: TestOutcome {
        let ran = parts.values.filter { $0 != .unavailable }
        if ran.isEmpty { return .unavailable }
        if ran.contains(.faulty) { return .fail }
        if ran.contains(.notConfirmed) { return .attention }
        return .pass
    }

    public func result(notes: String = "", finishedAt: Date = .now) -> TestResult {
        var metrics: [String: Double] = [:]
        for (part, result) in parts {
            switch result {
            case .ok: metrics[TestMetricKey.sensorOK(part)] = 1
            case .notConfirmed, .faulty: metrics[TestMetricKey.sensorOK(part)] = 0
            case .unavailable: break
            }
        }
        return TestResult(id: .sensors, outcome: outcome, metrics: metrics, notes: notes, finishedAt: finishedAt)
    }
}
