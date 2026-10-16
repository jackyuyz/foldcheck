import Foundation
import FoldKit

/// Context about the device for determining test applicability.
public struct DeviceContext: Sendable {
    /// Current fold state
    public var foldState: FoldState
    
    /// Device model identifier (e.g., "iPhone18,1")
    public var modelIdentifier: String
    
    /// iOS version
    public var osVersion: String
    
    /// Whether the camera is available
    public var isCameraAvailable: Bool
    
    /// Whether the microphone is available
    public var isMicrophoneAvailable: Bool
    
    /// Whether biometric authentication is available
    public var isBiometricAvailable: Bool
    
    /// The type of biometric authentication (e.g., "touchID", "faceID")
    public var biometricType: String?
    
    public init(
        foldState: FoldState = .noHinge,
        modelIdentifier: String = "",
        osVersion: String = "",
        isCameraAvailable: Bool = true,
        isMicrophoneAvailable: Bool = true,
        isBiometricAvailable: Bool = true,
        biometricType: String? = nil
    ) {
        self.foldState = foldState
        self.modelIdentifier = modelIdentifier
        self.osVersion = osVersion
        self.isCameraAvailable = isCameraAvailable
        self.isMicrophoneAvailable = isMicrophoneAvailable
        self.isBiometricAvailable = isBiometricAvailable
        self.biometricType = biometricType
    }
    
    /// Whether the device has a hinge (is a Duo)
    public var hasHinge: Bool {
        foldState.hasHinge
    }

    /// Whether the device reports Touch ID (enrolled or not).
    public var hasTouchID: Bool {
        biometricType == "touchID"
    }
    
    /// Create a mock context for testing
    public static func mock(hasHinge: Bool = false) -> DeviceContext {
        DeviceContext(
            foldState: hasHinge ? FoldState(posture: .fullyOpen, angleDegrees: 180) : .noHinge,
            modelIdentifier: hasHinge ? "iPhone19,1" : "iPhone17,1",
            osVersion: "27.0",
            isCameraAvailable: true,
            isMicrophoneAvailable: true,
            isBiometricAvailable: true,
            biometricType: "touchID"
        )
    }
}
