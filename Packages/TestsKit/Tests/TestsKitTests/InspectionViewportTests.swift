import XCTest
@testable import TestsKit

final class InspectionViewportTests: XCTestCase {
    func testBothOrientationsAndRounding() {
        for bounds in [CGRect(x: 0, y: 0, width: 402, height: 874), CGRect(x: 0, y: 0, width: 874, height: 402)] {
            XCTAssertEqual(InspectionViewport.evaluate(window: bounds.insetBy(dx: 0.5, dy: 0.5), screen: bounds, isIPad: false), .fullScreen)
        }
    }

    func testSplitFloatingOffsetAndUnknownWindowsCannotRun() {
        let screen = CGRect(x: 0, y: 0, width: 800, height: 900)
        for window in [CGRect(x: 0, y: 0, width: 400, height: 900), screen.offsetBy(dx: 20, dy: 0), CGRect.zero] {
            XCTAssertEqual(InspectionViewport.evaluate(window: window, screen: screen, isIPad: false), .requiresFullScreen)
        }
    }

    func testIPadCompatibilityCanTestOnlyItsWindow() {
        XCTAssertEqual(InspectionViewport.evaluate(window: CGRect(x: 100, y: 100, width: 400, height: 800), screen: CGRect(x: 0, y: 0, width: 1024, height: 1366), isIPad: true), .iPadCompatibility)
    }
}
