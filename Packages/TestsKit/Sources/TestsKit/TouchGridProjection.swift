import Foundation

/// Rotates a fixed test grid into the current canvas. Coverage stays in the original
/// grid's coordinates, so rotating cannot create or discard tested cells.
public struct TouchGridProjection: Sendable, Equatable {
    public let referenceSize: CGSize
    public let canvasSize: CGSize
    public let quarterTurns: Int

    public init(referenceSize: CGSize, canvasSize: CGSize, quarterTurns: Int) {
        self.referenceSize = referenceSize
        self.canvasSize = canvasSize
        self.quarterTurns = (quarterTurns % 4 + 4) % 4
    }

    public func pointInCanvas(_ point: CGPoint) -> CGPoint {
        guard referenceSize.width > 0, referenceSize.height > 0 else { return .zero }
        let x = point.x / referenceSize.width
        let y = point.y / referenceSize.height
        let normalized: CGPoint
        switch quarterTurns {
        case 1: normalized = CGPoint(x: 1 - y, y: x)
        case 2: normalized = CGPoint(x: 1 - x, y: 1 - y)
        case 3: normalized = CGPoint(x: y, y: 1 - x)
        default: normalized = CGPoint(x: x, y: y)
        }
        return CGPoint(x: normalized.x * canvasSize.width, y: normalized.y * canvasSize.height)
    }

    public func pointInReference(_ point: CGPoint) -> CGPoint {
        TouchGridProjection(referenceSize: canvasSize, canvasSize: referenceSize,
                            quarterTurns: -quarterTurns).pointInCanvas(point)
    }

    public func rectInCanvas(_ rect: CGRect) -> CGRect {
        let first = pointInCanvas(CGPoint(x: rect.minX, y: rect.minY))
        let opposite = pointInCanvas(CGPoint(x: rect.maxX, y: rect.maxY))
        return CGRect(x: min(first.x, opposite.x), y: min(first.y, opposite.y),
                      width: abs(first.x - opposite.x), height: abs(first.y - opposite.y))
    }
}
