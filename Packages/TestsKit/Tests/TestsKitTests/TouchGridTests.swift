import Testing
import Foundation
#if canImport(CoreGraphics)
import CoreGraphics  // Linux gets CGPoint/CGRect from Foundation
#endif
@testable import TestsKit

@Suite("Touch grid layout")
struct TouchGridLayoutTests {
    /// iPhone 17 Pro portrait, in points.
    let phone = CGSize(width: 402, height: 874)

    @Test("Cells are ~7 mm and tile the whole canvas without a crease")
    func standardGrid() {
        let layout = TouchGridLayout(size: phone, spec: .standard, includeCreaseBand: false)
        let ppmm = DisplaySpec.iPhonePointsPerMillimeter
        #expect(layout.creaseBandCellCount == 0)
        #expect(layout.cells.count == 10 * 21)
        for cell in layout.cells {
            #expect(abs(cell.rect.width / ppmm - 7) < 0.8)
            #expect(abs(cell.rect.height / ppmm - 7) < 0.8)
        }
        let area = layout.cells.reduce(0) { $0 + $1.rect.width * $1.rect.height }
        #expect(abs(area - phone.width * phone.height) < 0.5)
    }

    @Test("Crease band cells are half size and span ±10 mm around the fold")
    func creaseBand() throws {
        let layout = TouchGridLayout(size: phone, spec: .duoInner, includeCreaseBand: true)
        let ppmm = DisplaySpec.iPhonePointsPerMillimeter
        let band = layout.cells.filter(\.isCreaseBand)
        let normal = layout.cells.filter { !$0.isCreaseBand }
        #expect(!band.isEmpty)
        let bandMinX = try #require(band.map(\.rect.minX).min())
        let bandMaxX = try #require(band.map(\.rect.maxX).max())
        #expect(abs(bandMinX - (201 - 10 * ppmm)) < 0.01)
        #expect(abs(bandMaxX - (201 + 10 * ppmm)) < 0.01)
        let normalWidth = try #require(normal.first?.rect.width)
        let normalHeight = try #require(normal.first?.rect.height)
        for cell in band {
            #expect(abs(cell.rect.width / ppmm - 3.5) < 0.6)
            #expect(abs(cell.rect.height / ppmm - 3.5) < 0.6)
            #expect(cell.rect.width < normalWidth * 0.6)
            #expect(cell.rect.height < normalHeight * 0.6)
        }
        // Normal cells never overlap the band.
        for cell in normal {
            #expect(cell.rect.maxX <= bandMinX + 0.01 || cell.rect.minX >= bandMaxX - 0.01)
        }
        let area = layout.cells.reduce(0) { $0 + $1.rect.width * $1.rect.height }
        #expect(abs(area - phone.width * phone.height) < 0.5)
    }

    @Test("Without includeCreaseBand the Duo spec has no band")
    func bandOnlyWhenRequested() {
        let layout = TouchGridLayout(size: phone, spec: .duoInner, includeCreaseBand: false)
        #expect(layout.creaseBandCellCount == 0)
    }

    @Test("Horizontal crease puts the band across rows")
    func horizontalCrease() throws {
        let spec = DisplaySpec(crease: .init(axis: .horizontal, position: 0.5))
        let size = CGSize(width: 800, height: 600)
        let layout = TouchGridLayout(size: size, spec: spec, includeCreaseBand: true)
        let band = layout.cells.filter(\.isCreaseBand)
        let ppmm = DisplaySpec.iPhonePointsPerMillimeter
        let minY = try #require(band.map(\.rect.minY).min())
        let maxY = try #require(band.map(\.rect.maxY).max())
        #expect(abs(minY - (300 - 10 * ppmm)) < 0.01)
        #expect(abs(maxY - (300 + 10 * ppmm)) < 0.01)
        #expect(band.allSatisfy { $0.rect.width == size.width / CGFloat(Int((size.width / (3.5 * ppmm)).rounded())) })
    }

    @Test("Every cell's center maps back to that cell; outside points map to nil")
    func cellLookup() {
        for spec in [DisplaySpec.standard, .duoInner] {
            let layout = TouchGridLayout(size: phone, spec: spec, includeCreaseBand: true)
            for cell in layout.cells {
                #expect(layout.cellID(at: CGPoint(x: cell.rect.midX, y: cell.rect.midY)) == cell.id)
            }
            #expect(layout.cellID(at: CGPoint(x: -1, y: 10)) == nil)
            #expect(layout.cellID(at: CGPoint(x: 10, y: phone.height + 1)) == nil)
            // The far edges belong to the last cells, not to nothing.
            #expect(layout.cellID(at: CGPoint(x: phone.width, y: phone.height)) == layout.cells.last?.id)
        }
    }

    @Test("Duo fallback rotates the crease with the inner canvas")
    func rotatedDuoCrease() {
        for size in [CGSize(width: 956, height: 670), CGSize(width: 670, height: 956)] {
            let spec = DisplaySpec.duoInner(canvasSize: size)
            let layout = TouchGridLayout(size: size, spec: spec, includeCreaseBand: true)
            #expect(layout.axis == (size.width > size.height ? .vertical : .horizontal))
            var session = TouchGridSession(layout: layout)
            TouchGridSessionTests.swipeAllColumns(&session, size: size)
            #expect(session.isComplete)
            #expect(session.creaseBandCoverage == 1)
        }
    }

    @Test("System division overrides the assumed axis and center, even without a resize")
    func systemDivisionGeometry() throws {
        let size = CGSize(width: 800, height: 600)
        let initial = TouchGridLayout(size: size, spec: .duoInner(canvasSize: size), includeCreaseBand: true)
        var session = TouchGridSession(layout: initial)
        session.touch(at: CGPoint(x: 20, y: 20))
        // A horizontal region at y = 250, rather than the assumed vertical center.
        let spec = DisplaySpec.duoInner(canvasSize: size, divisionFrame: CGRect(x: 0, y: 245, width: 800, height: 10))
        let updated = TouchGridLayout(size: size, spec: spec, includeCreaseBand: true)
        session.relayout(updated)
        #expect(session.coveredCount == 0)
        #expect(updated.axis == .horizontal)
        let band = updated.cells.filter(\.isCreaseBand)
        let minY = try #require(band.map(\.rect.minY).min())
        let maxY = try #require(band.map(\.rect.maxY).max())
        #expect(abs((minY + maxY) / 2 - 250) < 0.01)
        // The identical geometry must preserve new input.
        session.touch(at: CGPoint(x: 20, y: 20))
        session.relayout(updated)
        #expect(session.coveredCount == 1)
        let vertical = DisplaySpec.duoInner(canvasSize: size, divisionFrame: CGRect(x: 310, y: 0, width: 0, height: 600))
        #expect(vertical.crease?.axis == .vertical)
        #expect(vertical.crease?.position == 310.0 / 800)
    }

    @Test("A band that runs off the canvas edge is clamped")
    func bandAtEdge() {
        let spec = DisplaySpec(crease: .init(axis: .vertical, position: 0.02))
        let layout = TouchGridLayout(size: phone, spec: spec, includeCreaseBand: true)
        #expect(layout.cells.allSatisfy { $0.rect.minX >= 0 && $0.rect.maxX <= phone.width + 0.01 })
        #expect(layout.creaseBandCellCount > 0)
    }

    @Test("Empty canvas yields a degenerate but safe layout")
    func emptyCanvas() {
        let layout = TouchGridLayout(size: .zero, spec: .duoInner, includeCreaseBand: true)
        #expect(layout.cells.isEmpty)
        #expect(layout.cellID(at: .zero) == nil)
        let session = TouchGridSession(layout: layout)
        #expect(!session.isComplete)
        #expect(session.coverage == 0)
    }
}

@Suite("Touch grid rotation projection")
struct TouchGridProjectionTests {
    @Test("Each quarter-turn keeps every cell at the same physical touch location")
    func physicalCells() {
        let size = CGSize(width: 670, height: 956)
        let layout = TouchGridLayout(size: size, spec: .duoInner(canvasSize: size), includeCreaseBand: true)
        for turns in 0..<4 {
            let canvas = turns.isMultiple(of: 2) ? size : CGSize(width: size.height, height: size.width)
            let projection = TouchGridProjection(referenceSize: size, canvasSize: canvas, quarterTurns: turns)
            for cell in layout.cells {
                let rect = projection.rectInCanvas(cell.rect)
                #expect(rect.minX >= -0.001 && rect.maxX <= canvas.width + 0.001)
                #expect(rect.minY >= -0.001 && rect.maxY <= canvas.height + 0.001)
                let input = projection.pointInReference(CGPoint(x: rect.midX, y: rect.midY))
                #expect(layout.cellID(at: input) == cell.id)
            }
            // An asymmetric point catches clockwise/counterclockwise and 180° mistakes.
            let point = projection.pointInCanvas(CGPoint(x: 0.2 * size.width, y: 0.3 * size.height))
            let expected = [CGPoint(x: 0.2, y: 0.3), CGPoint(x: 0.7, y: 0.2),
                            CGPoint(x: 0.8, y: 0.7), CGPoint(x: 0.3, y: 0.8)][turns]
            #expect(abs(point.x / canvas.width - expected.x) < 0.0001)
            #expect(abs(point.y / canvas.height - expected.y) < 0.0001)
        }
    }

    @Test("A run can reach 100% while rotating between every physical contact")
    func completeWhileRotating() {
        let size = CGSize(width: 956, height: 670)
        let layout = TouchGridLayout(size: size, spec: .duoInner(canvasSize: size), includeCreaseBand: true)
        var session = TouchGridSession(layout: layout)
        for (index, cell) in layout.cells.enumerated() {
            let turns = index % 4
            let canvas = turns.isMultiple(of: 2) ? size : CGSize(width: size.height, height: size.width)
            let projection = TouchGridProjection(referenceSize: size, canvasSize: canvas, quarterTurns: turns)
            let input = projection.pointInCanvas(CGPoint(x: cell.rect.midX, y: cell.rect.midY))
            let reference = projection.pointInReference(input)
            #expect(session.stroke(from: reference, to: reference) == [cell.id])
            #expect(session.coveredCount == index + 1)
            #expect(session.totalCount == layout.cells.count)
            // Touching the same physical cell again after a half turn adds no coverage.
            let reversed = TouchGridProjection(referenceSize: size, canvasSize: canvas, quarterTurns: turns + 2)
            let sameCell = reversed.pointInCanvas(CGPoint(x: cell.rect.midX, y: cell.rect.midY))
            #expect(session.stroke(from: reversed.pointInReference(sameCell),
                                   to: reversed.pointInReference(sameCell)).isEmpty)
        }
        #expect(session.isComplete)
        #expect(session.creaseBandCoverage == 1)
        #expect(session.result(id: .touchGridInner, display: .inner).outcome == .pass)
    }
}

@Suite("Touch grid session")
struct TouchGridSessionTests {
    let phone = CGSize(width: 402, height: 874)

    /// Vertical swipes from the middle to each edge, every 14 pt: the same pattern the UI test uses.
    static func swipeAllColumns(_ session: inout TouchGridSession, size: CGSize, step: CGFloat = 14) {
        var x: CGFloat = step / 2
        while x < size.width {
            session.stroke(from: CGPoint(x: x, y: size.height / 2), to: CGPoint(x: x, y: 0))
            session.stroke(from: CGPoint(x: x, y: size.height / 2), to: CGPoint(x: x, y: size.height))
            x += step
        }
    }

    @Test("Scripted swipes cover 100% of cells including the crease band (AC3)")
    func fullCoverageWithBand() throws {
        let layout = TouchGridLayout(size: phone, spec: .duoInner, includeCreaseBand: true)
        var session = TouchGridSession(layout: layout)
        Self.swipeAllColumns(&session, size: phone)
        #expect(session.isComplete)
        #expect(session.coverage == 1)
        #expect(session.creaseBandCoverage == 1)
        let result = session.result(id: .touchGridInner, display: .inner)
        #expect(result.outcome == .pass)
        #expect(result.metrics[TestMetricKey.coveragePercent] == 100)
        #expect(result.metrics[TestMetricKey.creaseBandCoverage] == 100)
        #expect(result.metrics[TestMetricKey.missedCells] == 0)
        #expect(result.metrics[TestMetricKey.creaseBandCells] == Double(layout.creaseBandCellCount))
        #expect(result.display == .inner)
    }

    @Test("A fast swipe sampled only at its end points still fills every cell between")
    func strokeInterpolates() {
        let layout = TouchGridLayout(size: phone, spec: .standard, includeCreaseBand: false)
        var session = TouchGridSession(layout: layout)
        let newlyCovered = session.stroke(from: CGPoint(x: 20, y: 1), to: CGPoint(x: 20, y: 873))
        #expect(newlyCovered.count == 21)
        #expect(Set(newlyCovered).count == 21)
        // Stroking the same path again covers nothing new.
        let again = session.stroke(from: CGPoint(x: 20, y: 1), to: CGPoint(x: 20, y: 873))
        #expect(again.isEmpty)
    }

    @Test("Diagonal stroke through the band covers band cells too")
    func diagonalThroughBand() {
        let layout = TouchGridLayout(size: phone, spec: .duoInner, includeCreaseBand: true)
        var session = TouchGridSession(layout: layout)
        session.stroke(from: CGPoint(x: 0, y: 0), to: CGPoint(x: phone.width, y: phone.height))
        #expect(session.creaseBandCovered > 0)
        #expect(!session.isComplete)
    }

    @Test("Single taps cover one cell each")
    func taps() throws {
        let layout = TouchGridLayout(size: phone, spec: .standard, includeCreaseBand: false)
        var session = TouchGridSession(layout: layout)
        let first = try #require(layout.cells.first)
        let firstTouch = session.touch(at: CGPoint(x: first.rect.midX, y: first.rect.midY))
        let secondTouch = session.touch(at: CGPoint(x: first.rect.midX + 1, y: first.rect.midY))
        #expect(firstTouch == first.id)
        #expect(secondTouch == nil)
        #expect(session.coveredCount == 1)
        #expect(session.missedCount == layout.cells.count - 1)
        #expect(session.missedCellIDs.first == 1)
    }

    @Test("Outcome: misses are Attention, or Fail when the user says areas don't respond")
    func outcomes() {
        #expect(TouchGridSession.outcome(missedCount: 0, reason: nil) == .pass)
        #expect(TouchGridSession.outcome(missedCount: 0, reason: .unresponsive) == .pass)
        #expect(TouchGridSession.outcome(missedCount: 3, reason: nil) == .attention)
        #expect(TouchGridSession.outcome(missedCount: 3, reason: .blockedByCase) == .attention)
        #expect(TouchGridSession.outcome(missedCount: 3, reason: .unresponsive) == .fail)
    }

    @Test("Partial run reports misses, rounds coverage down, and has no band metrics without a band")
    func partialResult() {
        let layout = TouchGridLayout(size: phone, spec: .standard, includeCreaseBand: false)
        var session = TouchGridSession(layout: layout)
        for cell in layout.cells.dropLast() {
            session.touch(at: CGPoint(x: cell.rect.midX, y: cell.rect.midY))
        }
        let result = session.result(id: .touchGridOuter, display: nil, missReason: .unresponsive)
        #expect(result.outcome == .fail)
        #expect(result.metrics[TestMetricKey.missedCells] == 1)
        #expect(result.metrics[TestMetricKey.coveragePercent] == 99.5)
        #expect(result.metrics[TestMetricKey.creaseBandCoverage] == nil)
        #expect(result.metrics[TestMetricKey.missReasonBlockedByCase] == 0)
        #expect(result.display == nil)
    }

    @Test("Multi-touch peak is tracked and capped at 10")
    func multiTouch() {
        var session = TouchGridSession(layout: TouchGridLayout(size: phone, spec: .standard, includeCreaseBand: false))
        session.recordSimultaneousTouches(3)
        session.recordSimultaneousTouches(1)
        #expect(session.maxSimultaneousTouches == 3)
        session.recordSimultaneousTouches(14)
        #expect(session.maxSimultaneousTouches == 10)
        #expect(session.result(id: .touchGridOuter, display: nil).metrics[TestMetricKey.maxTouches] == 10)
    }

    @Test("Relayout resets coverage only when the geometry changes")
    func relayout() {
        let layout = TouchGridLayout(size: phone, spec: .standard, includeCreaseBand: false)
        var session = TouchGridSession(layout: layout)
        session.touch(at: CGPoint(x: 5, y: 5))
        session.relayout(layout)
        #expect(session.coveredCount == 1)
        session.relayout(TouchGridLayout(size: CGSize(width: 874, height: 402), spec: .standard, includeCreaseBand: false))
        #expect(session.coveredCount == 0)
        #expect(session.totalCount == 21 * 10)
    }
}
