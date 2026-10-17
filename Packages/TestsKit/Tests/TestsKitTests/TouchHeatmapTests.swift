import Testing
import Foundation
@testable import TestsKit

@Test("Saved heatmap preserves physical contacts and dense crease cells")
func savedTouchHeatmap() throws {
    let layout = TouchGridLayout(size: CGSize(width: 800, height: 600), spec: .duoInner, includeCreaseBand: true)
    var session = TouchGridSession(layout: layout)
    session.touch(at: CGPoint(x: 20, y: 20))
    let result = session.result(id: .touchGridInner, display: .inner, landscape: false)
    let map = try #require(result.touchHeatmap)
    #expect(map.cells.count == layout.cells.count)
    #expect(map.cells.filter(\.covered).count == 1)
    #expect(map.cells.contains { $0.isCreaseBand })
    #expect(map.cells.allSatisfy { $0.x >= 0 && $0.y >= 0 && $0.x + $0.width <= 1.00001 && $0.y + $0.height <= 1.00001 })
    let decoded = try JSONDecoder().decode(TestResult.self, from: JSONEncoder().encode(result))
    #expect(decoded.touchHeatmap == map)
    #expect(session.result(id: .touchGridInner, display: .inner, landscape: true).touchHeatmap == map)
}

@Test("Old count-only records remain count-only")
func legacyTouchResults() throws {
    let result = TestResult(id: .touchGridOuter, outcome: .pass)
    let data = try JSONEncoder().encode(result)
    #expect(!String(decoding: data, as: UTF8.self).contains("touchHeatmap"))
    #expect(try JSONDecoder().decode(TestResult.self, from: data).touchHeatmap == nil)
}
