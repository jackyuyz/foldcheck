import Foundation
import CoreGraphics

/// One cell of the touch grid.
public struct TouchGridCell: Sendable, Equatable, Identifiable {
    public let id: Int
    public let rect: CGRect
    /// True for the half-size cells inside the crease band.
    public let isCreaseBand: Bool
}

/// Splits a canvas into ~7 mm cells, with half-size cells within the crease band (T1).
///
/// The canvas is cut into strips across the fold (columns for a vertical crease, rows for a
/// horizontal one). Each strip is then cut into cells along the fold. Regions are divided into
/// equal parts so there are no slivers at the edges or around the band.
public struct TouchGridLayout: Sendable, Equatable {
    struct Strip: Sendable, Equatable {
        var start: CGFloat
        var length: CGFloat
        var cellCount: Int
        var cellLength: CGFloat
        var firstCellID: Int
        var isCreaseBand: Bool
    }

    public let size: CGSize
    public let cells: [TouchGridCell]
    /// Axis of the fold the strips are cut against. `.vertical` when there is no crease.
    public let axis: DisplaySpec.CreaseAxis
    /// Nominal cell edge in points, outside the band.
    public let nominalCellSize: CGFloat
    let strips: [Strip]

    /// - Parameters:
    ///   - size: Canvas size in points.
    ///   - spec: Physical display description.
    ///   - cellSizeMM: Nominal cell edge (spec: ~7 mm).
    ///   - includeCreaseBand: Draw the dense band (only on a Duo inner display).
    public init(size: CGSize, spec: DisplaySpec, cellSizeMM: Double = 7, includeCreaseBand: Bool) {
        self.size = size
        let cell = CGFloat(max(cellSizeMM * spec.pointsPerMillimeter, 1))
        nominalCellSize = cell

        let crease = includeCreaseBand ? spec.crease : nil
        let axis = crease?.axis ?? .vertical
        self.axis = axis

        // "across" is perpendicular to the fold line; strips are laid out along it.
        let acrossLength = axis == .vertical ? size.width : size.height
        let alongLength = axis == .vertical ? size.height : size.width

        var regions: [(start: CGFloat, length: CGFloat, band: Bool)] = []
        if let crease, acrossLength > 0 {
            let center = CGFloat(crease.position) * acrossLength
            let half = CGFloat(crease.bandHalfWidthMM * spec.pointsPerMillimeter)
            let bandStart = min(max(center - half, 0), acrossLength)
            let bandEnd = min(max(center + half, 0), acrossLength)
            regions = [
                (0, bandStart, false),
                (bandStart, bandEnd - bandStart, true),
                (bandEnd, acrossLength - bandEnd, false),
            ]
        } else {
            regions = [(0, acrossLength, false)]
        }

        var strips: [Strip] = []
        var cells: [TouchGridCell] = []
        for region in regions where region.length >= 1 {
            let target = region.band ? cell / 2 : cell
            let stripCount = Self.divisions(region.length, target)
            let stripLength = region.length / CGFloat(stripCount)
            let cellCount = Self.divisions(alongLength, target)
            let cellLength = alongLength / CGFloat(cellCount)
            for s in 0..<stripCount {
                let strip = Strip(
                    start: region.start + CGFloat(s) * stripLength,
                    length: stripLength,
                    cellCount: cellCount,
                    cellLength: cellLength,
                    firstCellID: cells.count,
                    isCreaseBand: region.band
                )
                strips.append(strip)
                for c in 0..<cellCount {
                    let alongStart = CGFloat(c) * cellLength
                    let rect = axis == .vertical
                        ? CGRect(x: strip.start, y: alongStart, width: stripLength, height: cellLength)
                        : CGRect(x: alongStart, y: strip.start, width: cellLength, height: stripLength)
                    cells.append(TouchGridCell(id: cells.count, rect: rect, isCreaseBand: region.band))
                }
            }
        }
        self.strips = strips
        self.cells = cells
    }

    private static func divisions(_ length: CGFloat, _ target: CGFloat) -> Int {
        guard length > 0, target > 0 else { return 1 }
        return max(1, Int((length / target).rounded()))
    }

    /// Smallest cell edge in points (half-size inside the band). Strokes are sampled finer than this.
    public var minimumCellEdge: CGFloat {
        strips.map { min($0.length, $0.cellLength) }.min() ?? nominalCellSize
    }

    public var creaseBandCellCount: Int {
        cells.filter(\.isCreaseBand).count
    }

    /// The cell under `point`, or `nil` when it lies outside the canvas.
    public func cellID(at point: CGPoint) -> Int? {
        guard point.x >= 0, point.y >= 0, point.x <= size.width, point.y <= size.height else { return nil }
        let across = axis == .vertical ? point.x : point.y
        let along = axis == .vertical ? point.y : point.x
        guard let strip = strips.last(where: { $0.start <= across }) ?? strips.first else { return nil }
        let index = min(max(Int(along / strip.cellLength), 0), strip.cellCount - 1)
        return strip.firstCellID + index
    }
}
