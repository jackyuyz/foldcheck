import XCTest

/// M2: touch grid (T1), pixels (T2) and crease (T3), driven through `-FoldMock` on a regular
/// iPhone simulator. Mocking changes hinge signals only, so the "inner display" is the phone screen.
final class DisplayTouchUITests: XCTestCase {
    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    // MARK: T1

    /// AC3: scripted synthetic swipes fill 100% of the cells, including the half-size crease band.
    func testTouchGridDetectsEveryCellIncludingCreaseBand() throws {
        let app = launch(foldMock: "open")
        tap(app.buttons["home.quick.touch"])
        tap(app.buttons["test.start"])

        let canvas = element(app, "touchGrid.canvas")
        XCTAssertTrue(canvas.waitForExistence(timeout: 5))
        let before = try progress(of: canvas)
        XCTAssertEqual(before.covered, 0)
        XCTAssertGreaterThan(before.bandTotal, 0, "Open Duo should draw the crease band")

        swipeEveryColumn(app, canvas: canvas)

        let after = try progress(of: canvas)
        XCTAssertEqual(after.covered, after.total, "Every cell should register")
        XCTAssertEqual(after.bandCovered, after.bandTotal, "Every crease band cell should register")

        tap(app.buttons["touchGrid.finish"])
        tap(app.buttons["touchGrid.multiDone"])
        XCTAssertEqual(element(app, "result.outcome").label, "Pass")
        tap(app.buttons["result.continue"])

        let row = element(app, "summary.row.touchGridInner")
        XCTAssertTrue(row.waitForExistence(timeout: 5))
        XCTAssertTrue(row.label.contains("Pass"), row.label)
        XCTAssertTrue(row.label.contains("100% (\(after.total)/\(after.total))"), row.label)
        XCTAssertTrue(row.label.contains("Crease band 100%"), row.label)
    }

    /// Without a hinge the quick touch test is the plain grid (no band); unresponsive misses Fail.
    func testTouchGridWithoutHingeHasNoBandAndUnresponsiveMissesFail() throws {
        let app = launch(foldMock: "nohinge")
        tap(app.buttons["home.quick.touch"])
        XCTAssertTrue(app.staticTexts["Touch Grid (Outer)"].firstMatch.waitForExistence(timeout: 5))
        tap(app.buttons["test.start"])

        let canvas = element(app, "touchGrid.canvas")
        XCTAssertTrue(canvas.waitForExistence(timeout: 5))
        XCTAssertEqual(try progress(of: canvas).bandTotal, 0)

        let origin = app.coordinate(withNormalizedOffset: .zero)
        let frame = canvas.frame
        origin.withOffset(CGVector(dx: frame.midX, dy: frame.midY))
            .press(forDuration: 0.05, thenDragTo: origin.withOffset(CGVector(dx: frame.midX, dy: frame.minY + 1)))
        XCTAssertGreaterThan(try progress(of: canvas).covered, 0)

        tap(app.buttons["touchGrid.finish"])
        XCTAssertTrue(element(app, "touchGrid.missedTitle").waitForExistence(timeout: 5))
        tap(app.buttons["touchGrid.unresponsive"])
        tap(app.buttons["touchGrid.multiDone"])
        XCTAssertEqual(element(app, "result.outcome").label, "Fail")
        tap(app.buttons["result.continue"])

        let row = element(app, "summary.row.touchGridOuter")
        XCTAssertTrue(row.waitForExistence(timeout: 5))
        XCTAssertTrue(row.label.contains("Fail"), row.label)
        XCTAssertFalse(row.label.contains("Crease band"), row.label)
    }

    // MARK: T2

    func testPixelTestRecordsMarkedIssue() throws {
        let app = launch(foldMock: "nohinge")
        tap(app.buttons["home.quick.screen"])
        tap(app.buttons["test.start"])

        let canvas = element(app, "pixels.canvas")
        XCTAssertTrue(canvas.waitForExistence(timeout: 5))
        canvas.tap()
        for _ in 0..<6 {
            tap(app.buttons["pixels.next"])
        }

        XCTAssertEqual(element(app, "result.outcome").label, "Attention")
        XCTAssertTrue(element(app, "result.systemNotes").label.contains("1 spots"))
        tap(app.buttons["result.continue"])

        let row = element(app, "summary.row.pixels")
        XCTAssertTrue(row.waitForExistence(timeout: 5))
        XCTAssertTrue(row.label.contains("Attention"), row.label)
        XCTAssertTrue(row.label.contains("Issues marked 1"), row.label)
    }

    // MARK: Full inspection

    /// AC5 (for M2): on a non-Duo iPhone the hinge tests are N/A and the screen tests run.
    func testFullInspectionWithoutHinge() throws {
        let app = launch(foldMock: "nohinge")
        tap(app.buttons["home.start"])
        XCTAssertTrue(app.staticTexts["Test 1 of 2"].waitForExistence(timeout: 5))

        tap(app.buttons["test.skip"])
        XCTAssertTrue(app.staticTexts["Test 2 of 2"].waitForExistence(timeout: 5))
        tap(app.buttons["test.start"])
        for _ in 0..<6 {
            tap(app.buttons["pixels.next"])
        }
        XCTAssertEqual(element(app, "result.outcome").label, "Pass")
        tap(app.buttons["result.continue"])

        XCTAssertTrue(element(app, "summary.device").waitForExistence(timeout: 5))
        XCTAssertTrue(element(app, "summary.device").label.contains("iPhone"))
        assertRow(app, "touchGridOuter", contains: "Skipped")
        assertRow(app, "pixels", contains: "Pass")
        assertRow(app, "touchGridInner", contains: "Not Applicable")
        assertRow(app, "crease", contains: "Not Applicable")
        assertRow(app, "hingeSweep", contains: "Not Applicable")
        assertRow(app, "cameras", contains: "Skipped")
    }

    // MARK: T3

    func testCreaseVisibilityOnOpenDuo() throws {
        let app = launch(foldMock: "open")
        tap(app.buttons["home.start"])
        XCTAssertTrue(app.staticTexts["Test 1 of 4"].waitForExistence(timeout: 5))
        // The outer-display grid asks an open Duo to close first.
        XCTAssertTrue(element(app, "test.foldPrompt").waitForExistence(timeout: 5))

        for _ in 0..<3 {
            tap(app.buttons["test.skip"])
        }
        XCTAssertTrue(app.staticTexts["Test 4 of 4"].waitForExistence(timeout: 5))
        tap(app.buttons["test.start"])

        for rating in [2, 1, 3] {
            tap(app.buttons["crease.rating.\(rating)"])
            tap(app.buttons["crease.next"])
        }

        XCTAssertEqual(element(app, "result.outcome").label, "Pass")
        XCTAssertTrue(app.staticTexts["2 / 5 (max 3)"].exists)
        tap(app.buttons["result.continue"])

        assertRow(app, "crease", contains: "Pass")
        assertRow(app, "hingeSweep", contains: "Skipped")
    }

    // MARK: Helpers

    private func launch(foldMock: String) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = ["-UITestMode", "1", "-FoldMock", foldMock]
        app.launch()
        return app
    }

    private func element(_ app: XCUIApplication, _ identifier: String) -> XCUIElement {
        app.descendants(matching: .any)[identifier].firstMatch
    }

    private func tap(_ element: XCUIElement, file: StaticString = #filePath, line: UInt = #line) {
        XCTAssertTrue(element.waitForExistence(timeout: 5), "Missing \(element)", file: file, line: line)
        element.tap()
    }

    private func assertRow(_ app: XCUIApplication, _ test: String, contains text: String, line: UInt = #line) {
        let row = element(app, "summary.row.\(test)")
        XCTAssertTrue(row.waitForExistence(timeout: 5), "Missing row \(test)", line: line)
        XCTAssertTrue(row.label.contains(text), "\(test): \(row.label)", line: line)
    }

    /// Vertical drags from the middle to each edge, 14 pt apart: narrower than the half-size
    /// band cells (~21 pt), so every column is crossed. Starting in the middle avoids the
    /// system edge gestures.
    private func swipeEveryColumn(_ app: XCUIApplication, canvas: XCUIElement) {
        let origin = app.coordinate(withNormalizedOffset: .zero)
        let frame = canvas.frame
        var x: CGFloat = 7
        while x < frame.width {
            let middle = origin.withOffset(CGVector(dx: frame.minX + x, dy: frame.midY))
            let top = origin.withOffset(CGVector(dx: frame.minX + x, dy: frame.minY + 1))
            let bottom = origin.withOffset(CGVector(dx: frame.minX + x, dy: frame.maxY - 1))
            middle.press(forDuration: 0.05, thenDragTo: top, withVelocity: .fast, thenHoldForDuration: 0)
            middle.press(forDuration: 0.05, thenDragTo: bottom, withVelocity: .fast, thenHoldForDuration: 0)
            x += 14
        }
    }

    private struct GridProgress {
        var covered: Int
        var total: Int
        var bandCovered: Int
        var bandTotal: Int
    }

    /// Parses the canvas accessibility value: "N of M cells[, Crease band b/B]".
    private func progress(of canvas: XCUIElement) throws -> GridProgress {
        let value = try XCTUnwrap(canvas.value as? String)
        let numbers = value.split(whereSeparator: { !$0.isNumber }).compactMap { Int($0) }
        XCTAssertTrue(numbers.count == 2 || numbers.count == 4, value)
        return GridProgress(
            covered: numbers[0],
            total: numbers[1],
            bandCovered: numbers.count == 4 ? numbers[2] : 0,
            bandTotal: numbers.count == 4 ? numbers[3] : 0
        )
    }
}
