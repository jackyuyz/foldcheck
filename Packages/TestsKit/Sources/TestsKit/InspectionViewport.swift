import Foundation

/// Display tests must measure the display, rather than a Split View / floating window.
/// iPhone compatibility mode on iPad can only measure its own window, which is disclosed.
public enum InspectionViewport: Equatable, Sendable {
    case fullScreen, requiresFullScreen, iPadCompatibility

    public static func evaluate(window: CGRect, screen: CGRect, isIPad: Bool, tolerance: CGFloat = 2) -> Self {
        if isIPad { return .iPadCompatibility }
        guard window.width > 0, window.height > 0, screen.width > 0, screen.height > 0 else {
            return .requiresFullScreen
        }
        let matches = abs(window.minX - screen.minX) <= tolerance
            && abs(window.minY - screen.minY) <= tolerance
            && abs(window.width - screen.width) <= tolerance
            && abs(window.height - screen.height) <= tolerance
        return matches ? .fullScreen : .requiresFullScreen
    }
}
