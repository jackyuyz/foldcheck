import Foundation

/// Physical description of a display, used to size touch-grid cells in millimetres
/// and to locate the crease band on the Duo's inner display.
public struct DisplaySpec: Codable, Sendable, Equatable {
    /// Orientation of the fold line within the canvas.
    public enum CreaseAxis: String, Codable, Sendable, Equatable {
        /// The fold runs top-to-bottom (book-style fold seen in the mockups).
        case vertical
        /// The fold runs left-to-right.
        case horizontal
    }

    /// Where the crease sits on a display.
    public struct Crease: Codable, Sendable, Equatable {
        public var axis: CreaseAxis
        /// Position of the fold line across the canvas, normalized 0…1
        /// (x for a vertical crease, y for a horizontal one).
        public var position: Double
        /// Half-width of the dense band around the fold, in millimetres.
        public var bandHalfWidthMM: Double

        public init(axis: CreaseAxis = .vertical, position: Double = 0.5, bandHalfWidthMM: Double = 10) {
            self.axis = axis
            self.position = position
            self.bandHalfWidthMM = bandHalfWidthMM
        }
    }

    /// Layout points per physical millimetre. Not available from any API, so it comes from
    /// the spec table. iPhones are ~460 ppi at @3x, i.e. ~153 pt/inch ≈ 6.04 pt/mm.
    public var pointsPerMillimeter: Double

    /// The crease, or `nil` for a display without one.
    public var crease: Crease?

    public init(pointsPerMillimeter: Double = DisplaySpec.iPhonePointsPerMillimeter, crease: Crease? = nil) {
        self.pointsPerMillimeter = pointsPerMillimeter
        self.crease = crease
    }

    public static let iPhonePointsPerMillimeter = 460.0 / 3.0 / 25.4

    /// Any flat iPhone display, and the Duo's outer display.
    public static let standard = DisplaySpec()

    /// The Duo's inner display: fold through the middle, dense cells within ±10 mm.
    /// Default book-style geometry; use `duoInner(canvasSize:divisionFrame:)` for a live canvas.
    public static let duoInner = DisplaySpec(crease: Crease())

    /// Resolve the physical fold in canvas coordinates, including inactive regions on a flat
    /// inner display. Before the system supplies a region, Duo's portrait canvas has a
    /// horizontal fold and its landscape canvas has a vertical fold.
    public static func duoInner(canvasSize: CGSize, divisionFrame: CGRect? = nil) -> DisplaySpec {
        var crease = Crease(axis: canvasSize.width >= canvasSize.height ? .vertical : .horizontal)
        if let frame = divisionFrame,
           !frame.isNull, !frame.isInfinite, frame.width != frame.height,
           canvasSize.width > 0, canvasSize.height > 0,
           frame.midX >= 0, frame.midX <= canvasSize.width,
           frame.midY >= 0, frame.midY <= canvasSize.height {
            crease.axis = frame.width > frame.height ? .horizontal : .vertical
            crease.position = crease.axis == .vertical
                ? Double(frame.midX / canvasSize.width)
                : Double(frame.midY / canvasSize.height)
        }
        return DisplaySpec(crease: crease)
    }
}
