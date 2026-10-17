import SwiftUI

/// The slider's display range, not a claim about hinge sensor accuracy or physical limits.
public enum ManualHingeAngle {
    public static func clamped(_ angle: Double?) -> Double {
        guard let angle, angle.isFinite else { return 90 }
        return min(max(angle, 0), 180)
    }
}

/// Shared manual input only. The caller must label resulting samples as manual, and supplies
/// localized text. It never calls a hinge API or pretends that a slider is a sensor reading.
public struct ManualHingeControl: View {
    @Binding private var angle: Double
    private let title: String

    public init(angle: Binding<Double>, title: String) {
        _angle = angle
        self.title = title
    }

    public var body: some View {
        Slider(value: $angle, in: 0...180, step: 1) {
            Text(title)
        } minimumValueLabel: {
            Text(verbatim: "0°")
        } maximumValueLabel: {
            Text(verbatim: "180°")
        }
    }
}
