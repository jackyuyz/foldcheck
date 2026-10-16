import Foundation

/// Maps device model identifiers to friendly names.
public struct DeviceNames: Sendable {
    /// Known device model mappings
    /// These would be updated as new devices are released
    public static let models: [String: String] = [
        // iPhone 18 Pro series and iPhone Duo (2026), as reported by the Xcode 27.1 RC
        // simulators. Not yet checked against real hardware.
        "iPhone19,2": "iPhone 18 Pro",
        "iPhone19,3": "iPhone 18 Pro Max",
        "iPhone19,4": "iPhone Duo",

        // iPhone 17 series and iPhone Air (2025)
        "iPhone18,1": "iPhone 17 Pro",
        "iPhone18,2": "iPhone 17 Pro Max",
        "iPhone18,3": "iPhone 17",
        "iPhone18,4": "iPhone Air",
        
        // iPhone 16 series (2024)
        "iPhone17,1": "iPhone 16 Pro",
        "iPhone17,2": "iPhone 16 Pro Max",
        "iPhone17,3": "iPhone 16",
        "iPhone17,4": "iPhone 16 Plus",
        "iPhone17,5": "iPhone 16e",
        
        // iPhone 15 series (2023)
        "iPhone15,4": "iPhone 15",
        "iPhone15,5": "iPhone 15 Plus",
        "iPhone16,1": "iPhone 15 Pro",
        "iPhone16,2": "iPhone 15 Pro Max",
        
        // Simulator
        "x86_64": "Simulator (Intel)",
        "arm64": "Simulator (Apple Silicon)"
    ]
    
    /// Get the friendly name for a device model identifier
    public static func friendlyName(for modelIdentifier: String) -> String {
        if let name = models[modelIdentifier] {
            return name
        }
        
        // Try to extract a reasonable fallback
        if modelIdentifier.hasPrefix("iPhone") {
            return "iPhone (\(modelIdentifier))"
        } else if modelIdentifier.hasPrefix("iPad") {
            return "iPad (\(modelIdentifier))"
        }
        
        return modelIdentifier
    }
    
    /// Check if a model identifier is a known iPhone Duo. The iPhone 18 Pro models share the
    /// `iPhone19,` prefix, so this matches exact identifiers. Whether a device has a hinge
    /// comes from the hinge API, not from this table.
    public static func isDuo(modelIdentifier: String) -> Bool {
        duoModels.contains(modelIdentifier)
    }

    private static let duoModels: Set<String> = ["iPhone19,4"]
}
