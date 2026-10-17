import Foundation

/// The physical grid chosen at test start. Coordinates are normalized to that grid,
/// so rotation cannot move a recorded contact to another physical cell.
public struct TouchHeatmap: Codable, Sendable, Equatable {
    public struct Cell: Codable, Sendable, Equatable {
        public var x: Double
        public var y: Double
        public var width: Double
        public var height: Double
        public var covered: Bool
        public var isCreaseBand: Bool
    }

    public var aspectRatio: Double
    public var cells: [Cell]

    public init(layout: TouchGridLayout, covered: Set<Int>) {
        aspectRatio = layout.size.height > 0 ? Double(layout.size.width / layout.size.height) : 1
        guard layout.size.width > 0, layout.size.height > 0 else { cells = []; return }
        cells = layout.cells.map {
            Cell(x: Double($0.rect.minX / layout.size.width), y: Double($0.rect.minY / layout.size.height),
                 width: Double($0.rect.width / layout.size.width), height: Double($0.rect.height / layout.size.height),
                 covered: covered.contains($0.id), isCreaseBand: $0.isCreaseBand)
        }
    }
}
