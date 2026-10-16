import Foundation

/// One camera found on the device (T5).
public struct CameraInfo: Codable, Sendable, Equatable, Identifiable {
    public enum Position: String, Codable, Sendable, Equatable {
        case back, front, unspecified
    }

    /// `AVCaptureDevice.uniqueID`.
    public var id: String
    /// `AVCaptureDevice.localizedName`, already localized by the system.
    public var name: String
    public var position: Position

    public init(id: String, name: String, position: Position) {
        self.id = id
        self.name = name
        self.position = position
    }
}

/// Brightness and sharpness of one captured frame.
public struct FrameStats: Codable, Sendable, Equatable {
    /// Mean luminance, 0 (black) … 1 (white).
    public var meanLuma: Double
    /// Mean absolute Laplacian of the luminance, 0 … 1. Higher means more detail in focus.
    public var sharpness: Double

    public init(meanLuma: Double, sharpness: Double) {
        self.meanLuma = meanLuma
        self.sharpness = sharpness
    }
}

/// Pure functions over an 8-bit grayscale frame (the camera's luma plane, downsampled).
public enum FrameAnalysis {
    /// - Parameters:
    ///   - gray: Row-major luminance values, `width * height` long.
    public static func stats(gray: [UInt8], width: Int, height: Int) -> FrameStats? {
        guard width > 2, height > 2, gray.count >= width * height else { return nil }
        var sum = 0
        for value in gray.prefix(width * height) { sum += Int(value) }
        let mean = Double(sum) / Double(width * height) / 255

        // 4-neighbour Laplacian over the interior.
        var laplacian = 0
        for y in 1..<(height - 1) {
            for x in 1..<(width - 1) {
                let i = y * width + x
                let center = 4 * Int(gray[i])
                let neighbours = Int(gray[i - 1]) + Int(gray[i + 1]) + Int(gray[i - width]) + Int(gray[i + width])
                laplacian += abs(center - neighbours)
            }
        }
        let interior = Double((width - 2) * (height - 2))
        // A single pixel's Laplacian is at most 4 * 255.
        let sharpness = Double(laplacian) / interior / (4 * 255)
        return FrameStats(meanLuma: mean, sharpness: sharpness)
    }
}

/// What happened to one camera during T5.
public enum CameraCheck: Codable, Sendable, Equatable {
    /// A frame arrived and the user said the picture looked right.
    case looksRight(FrameStats)
    /// A frame arrived but the user said the picture looked wrong (blurry, spots, dark).
    case looksWrong(FrameStats)
    /// The camera opened but no frame arrived, or it failed to start.
    case noFrame
    /// The system says this camera can't be used right now (e.g. the inner camera while closed).
    case notAvailableNow

    var stats: FrameStats? {
        switch self {
        case .looksRight(let stats), .looksWrong(let stats): return stats
        case .noFrame, .notAvailableNow: return nil
        }
    }
}

/// State of one camera test run (T5): each camera is opened in turn and checked.
public struct CameraTestSession: Sendable, Equatable {
    public let cameras: [CameraInfo]
    public private(set) var checks: [String: CameraCheck] = [:]

    public init(cameras: [CameraInfo]) {
        self.cameras = cameras
    }

    /// The first camera without a check yet.
    public var currentCamera: CameraInfo? {
        cameras.first { checks[$0.id] == nil }
    }

    public var isFinished: Bool { currentCamera == nil }

    public mutating func record(_ check: CameraCheck, for camera: CameraInfo) {
        checks[camera.id] = check
    }

    /// No cameras at all is Unavailable (the simulator has none); any camera without a frame
    /// is Fail; any picture the user called wrong is Attention.
    public static func outcome(cameraCount: Int, checks: [CameraCheck]) -> TestOutcome {
        guard cameraCount > 0 else { return .unavailable }
        let tested = checks.filter { $0 != .notAvailableNow }
        if tested.isEmpty { return .notApplicable }
        if tested.contains(.noFrame) { return .fail }
        if tested.contains(where: { if case .looksWrong = $0 { return true } else { return false } }) {
            return .attention
        }
        return .pass
    }

    public func result(notes: String = "", finishedAt: Date = .now) -> TestResult {
        let ordered = cameras.compactMap { checks[$0.id] }
        var metrics: [String: Double] = [
            TestMetricKey.camerasAvailable: Double(cameras.count),
            TestMetricKey.camerasTested: Double(ordered.filter { $0 != .notAvailableNow }.count),
        ]
        for (n, camera) in cameras.enumerated() {
            guard let check = checks[camera.id] else { continue }
            switch check {
            case .looksRight: metrics[TestMetricKey.cameraOK(n)] = 1
            case .looksWrong, .noFrame: metrics[TestMetricKey.cameraOK(n)] = 0
            case .notAvailableNow: break
            }
            if let stats = check.stats {
                metrics[TestMetricKey.cameraBrightness(n)] = stats.meanLuma
                metrics[TestMetricKey.cameraSharpness(n)] = stats.sharpness
            }
        }
        return TestResult(
            id: .cameras,
            outcome: Self.outcome(cameraCount: cameras.count, checks: ordered),
            metrics: metrics,
            notes: notes,
            finishedAt: finishedAt
        )
    }
}
