import Foundation
#if canImport(CoreGraphics)
import CoreGraphics  // Linux gets CGPoint/CGRect from Foundation
#endif

/// The user's explanation when they finish the touch grid with cells still missed.
public enum TouchGridMissReason: String, Codable, Sendable, Equatable {
    /// A case or screen protector edge stops the finger reaching edge cells.
    case blockedByCase
    /// The user tried and some areas never responded.
    case unresponsive
}

/// State of one touch-grid run (T1): which cells were touched, and the multi-touch peak.
public struct TouchGridSession: Sendable, Equatable {
    public private(set) var layout: TouchGridLayout
    public private(set) var covered: Set<Int> = []
    public private(set) var maxSimultaneousTouches = 0

    public init(layout: TouchGridLayout) {
        self.layout = layout
    }

    // MARK: Input

    /// Marks the cell under `point`. Returns the cell ID if it was newly covered.
    @discardableResult
    public mutating func touch(at point: CGPoint) -> Int? {
        guard let id = layout.cellID(at: point), covered.insert(id).inserted else { return nil }
        return id
    }

    /// Marks every cell along the segment, so fast swipes don't skip cells between touch samples.
    /// Returns the newly covered cell IDs in order.
    @discardableResult
    public mutating func stroke(from start: CGPoint, to end: CGPoint) -> [Int] {
        let dx = end.x - start.x
        let dy = end.y - start.y
        let distance = (dx * dx + dy * dy).squareRoot()
        let step = max(layout.minimumCellEdge / 3, 1)
        let samples = max(1, Int((distance / step).rounded(.up)))
        var newlyCovered: [Int] = []
        for i in 0...samples {
            let t = CGFloat(i) / CGFloat(samples)
            if let id = touch(at: CGPoint(x: start.x + dx * t, y: start.y + dy * t)) {
                newlyCovered.append(id)
            }
        }
        return newlyCovered
    }

    /// Records how many fingers are on the screen right now (capped at 10, as in the spec).
    public mutating func recordSimultaneousTouches(_ count: Int) {
        maxSimultaneousTouches = max(maxSimultaneousTouches, min(count, 10))
    }

    /// Clears coverage, keeping the multi-touch peak.
    public mutating func resetCoverage() {
        covered.removeAll()
    }

    /// Replaces the grid definition, clearing IDs from the old grid. Ordinary rotation
    /// uses TouchGridProjection to preserve the original layout and coverage instead.
    public mutating func relayout(_ newLayout: TouchGridLayout) {
        guard newLayout != layout else { return }
        layout = newLayout
        covered.removeAll()
    }

    // MARK: Progress

    public var totalCount: Int { layout.cells.count }
    public var coveredCount: Int { covered.count }
    public var missedCount: Int { totalCount - coveredCount }
    public var isComplete: Bool { totalCount > 0 && missedCount == 0 }

    /// Fraction 0…1 of all cells covered.
    public var coverage: Double {
        totalCount == 0 ? 0 : Double(coveredCount) / Double(totalCount)
    }

    public var missedCellIDs: [Int] {
        layout.cells.map(\.id).filter { !covered.contains($0) }
    }

    public var creaseBandTotal: Int { layout.creaseBandCellCount }

    public var creaseBandCovered: Int {
        layout.cells.filter { $0.isCreaseBand && covered.contains($0.id) }.count
    }

    /// Fraction 0…1 of the crease band covered, or `nil` without a band.
    public var creaseBandCoverage: Double? {
        creaseBandTotal == 0 ? nil : Double(creaseBandCovered) / Double(creaseBandTotal)
    }

    // MARK: Result

    /// Pass when every cell registered. With misses, the user's explanation decides:
    /// a case blocking the edges is Attention, unresponsive areas are Fail, and no explanation is Attention.
    public static func outcome(missedCount: Int, reason: TouchGridMissReason?) -> TestOutcome {
        guard missedCount > 0 else { return .pass }
        switch reason {
        case .unresponsive: return .fail
        case .blockedByCase, nil: return .attention
        }
    }

    public func result(
        id: TestID,
        display: DisplayKind?,
        missReason: TouchGridMissReason? = nil,
        landscape: Bool = false,
        notes: String = "",
        finishedAt: Date = .now
    ) -> TestResult {
        var metrics: [String: Double] = [
            TestMetricKey.cellsCovered: Double(coveredCount),
            TestMetricKey.totalCells: Double(totalCount),
            TestMetricKey.missedCells: Double(missedCount),
            TestMetricKey.coveragePercent: Self.percent(coverage),
            TestMetricKey.maxTouches: Double(maxSimultaneousTouches),
            TestMetricKey.cellSizePoints: Double(layout.nominalCellSize),
            TestMetricKey.orientationLandscape: landscape ? 1 : 0,
        ]
        if let band = creaseBandCoverage {
            metrics[TestMetricKey.creaseBandCoverage] = Self.percent(band)
            metrics[TestMetricKey.creaseBandCells] = Double(creaseBandTotal)
            metrics[TestMetricKey.creaseBandMissed] = Double(creaseBandTotal - creaseBandCovered)
        }
        let reason = missedCount > 0 ? missReason : nil
        if let reason {
            metrics[TestMetricKey.missReasonBlockedByCase] = reason == .blockedByCase ? 1 : 0
        }
        return TestResult(
            id: id,
            outcome: Self.outcome(missedCount: missedCount, reason: reason),
            metrics: metrics,
            notes: notes,
            display: display,
            finishedAt: finishedAt,
            touchHeatmap: TouchHeatmap(layout: layout, covered: covered)
        )
    }

    /// Percentage rounded to one decimal, so 99.96% never displays as 100%.
    static func percent(_ fraction: Double) -> Double {
        (fraction * 1000).rounded(.down) / 10
    }
}
