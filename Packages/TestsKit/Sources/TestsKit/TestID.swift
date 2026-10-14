import Foundation

/// Identifier for each inspection test in FoldCheck.
public enum TestID: String, Codable, CaseIterable, Sendable, Equatable {
    /// Touch grid test on outer display
    case touchGridOuter
    
    /// Touch grid test on inner display (with crease band)
    case touchGridInner
    
    /// Dead/stuck pixels and uniformity test
    case pixels
    
    /// Crease visibility assessment
    case crease
    
    /// Hinge sweep continuity test
    case hingeSweep
    
    /// Camera functionality test
    case cameras
    
    /// Audio (speakers and microphone) test
    case audio
    
    /// Touch ID biometric test
    case touchID
    
    /// Sensors and haptics test
    case sensors
    
    /// Physical buttons test (volume, etc.)
    case buttons
    
    /// Human-readable display name for the test
    public var displayName: String {
        switch self {
        case .touchGridOuter: return "Touch Grid (Outer)"
        case .touchGridInner: return "Touch Grid (Inner)"
        case .pixels: return "Pixels & Uniformity"
        case .crease: return "Crease Visibility"
        case .hingeSweep: return "Hinge Sweep"
        case .cameras: return "Cameras"
        case .audio: return "Audio"
        case .touchID: return "Touch ID"
        case .sensors: return "Sensors & Haptics"
        case .buttons: return "Buttons"
        }
    }
    
    /// Brief description of what the test checks
    public var testDescription: String {
        switch self {
        case .touchGridOuter:
            return "Tests touch sensitivity across the outer display by filling a grid."
        case .touchGridInner:
            return "Tests touch sensitivity across the inner display with dense cells along the crease."
        case .pixels:
            return "Checks for dead or stuck pixels using solid color screens."
        case .crease:
            return "Evaluates the visibility of the fold crease at different viewing angles."
        case .hingeSweep:
            return "Tests hinge continuity by slowly opening and closing the device."
        case .cameras:
            return "Verifies all cameras capture images correctly."
        case .audio:
            return "Tests speakers with tones and microphone with recording."
        case .touchID:
            return "Verifies Touch ID enrollment and functionality."
        case .sensors:
            return "Checks accelerometer, gyroscope, and haptic feedback."
        case .buttons:
            return "Tests volume button detection."
        }
    }
    
    /// Whether this test requires a hinge (Duo-only)
    public var requiresHinge: Bool {
        switch self {
        case .touchGridInner, .crease, .hingeSweep:
            return true
        case .touchGridOuter, .pixels, .cameras, .audio, .touchID, .sensors, .buttons:
            return false
        }
    }
    
    /// Estimated duration of the test in seconds
    public var estimatedDurationSeconds: Int {
        switch self {
        case .touchGridOuter, .touchGridInner: return 45
        case .pixels: return 30
        case .crease: return 60
        case .hingeSweep: return 60
        case .cameras: return 45
        case .audio: return 30
        case .touchID: return 15
        case .sensors: return 20
        case .buttons: return 15
        }
    }
    
    /// Default order for running tests in an inspection
    public static var defaultOrder: [TestID] {
        [
            .touchGridOuter,
            .touchGridInner,
            .pixels,
            .crease,
            .hingeSweep,
            .cameras,
            .audio,
            .touchID,
            .sensors,
            .buttons
        ]
    }
}
