import Foundation

/// Maps device model identifiers to friendly names.
public struct DeviceNames: Sendable {
    /// Known device model mappings
    /// These would be updated as new devices are released
    public static let models: [String: String] = [
        // iPhone Duo (hypothetical model numbers)
        "iPhone19,1": "iPhone 19 Duo",
        "iPhone19,2": "iPhone 19 Duo",
        
        // iPhone 18 series
        "iPhone18,1": "iPhone 18",
        "iPhone18,2": "iPhone 18 Plus",
        "iPhone18,3": "iPhone 18 Pro",
        "iPhone18,4": "iPhone 18 Pro Max",
        
        // iPhone 17 series
        "iPhone17,1": "iPhone 17",
        "iPhone17,2": "iPhone 17 Plus",
        "iPhone17,3": "iPhone 17 Pro",
        "iPhone17,4": "iPhone 17 Pro Max",
        
        // iPhone 16 series
        "iPhone16,1": "iPhone 16",
        "iPhone16,2": "iPhone 16 Plus",
        "iPhone16,3": "iPhone 16 Pro",
        "iPhone16,4": "iPhone 16 Pro Max",
        
        // iPhone 15 series
        "iPhone15,4": "iPhone 15",
        "iPhone15,5": "iPhone 15 Plus",
        "iPhone15,6": "iPhone 15 Pro",
        "iPhone15,7": "iPhone 15 Pro Max",
        
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
    
    /// Check if a model identifier likely represents an iPhone Duo
    public static func isDuo(modelIdentifier: String) -> Bool {
        // Hypothetical: iPhone 19 series is the Duo
        return modelIdentifier.hasPrefix("iPhone19,")
    }
}
