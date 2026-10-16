import XCTest

/// M3: hinge sweep (T4, AC2) and fold counter (F5, AC7), driven by `-FoldMock` on a regular
/// iPhone simulator. The hinge test replays the mock's launch script whenever a sweep starts.
final class HingeFoldUITests: XCTestCase {
    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    // MARK: T4

    func testHingeSweepPassesWithMockSweep() throws {
        let app = launch(["-FoldMock", "sweep:10-180:6"])
        let result = try runHingeTest(app)
        XCTAssertEqual(result, "Pass")
        XCTAssertTrue(app.staticTexts["100%"].exists, "Continuity should be 100%")
        XCTAssertTrue(element(app, "hinge.chart").exists)
        tap(app.buttons["result.continue"])
        assertRow(app, "hingeSweep", contains: "Pass")
        assertRow(app, "hingeSweep", contains: "Continuity 100%")
    }

    /// AC2: a 25° gap is Attention, not Fail.
    func testGappyScriptIsAttention() throws {
        let app = launch(["-FoldMock", "script:gappy"])
        XCTAssertEqual(try runHingeTest(app), "Attention")
        tap(app.buttons["result.continue"])
        assertRow(app, "hingeSweep", contains: "Attention")
        assertRow(app, "hingeSweep", contains: "Max Gap 2")
    }

    /// AC2: non-monotonic jumps are Attention.
    func testJumpyScriptIsAttention() throws {
        let app = launch(["-FoldMock", "script:jumpy"])
        XCTAssertEqual(try runHingeTest(app), "Attention")
    }

    /// AC2: no usable data is Unavailable (with a retry), never Fail.
    func testStaticHingeIsUnavailableWithRetry() throws {
        let app = launch(["-FoldMock", "open"])
        tap(app.buttons["home.quick.hinge"])
        tap(app.buttons["test.start"])
        tap(app.buttons["hinge.next"])
        tap(app.buttons["hinge.next"])
        tap(app.buttons["hinge.holdStart"])

        XCTAssertTrue(element(app, "hinge.unavailableTitle").waitForExistence(timeout: 10))
        tap(app.buttons["hinge.retry"])
        XCTAssertEqual(element(app, "hinge.step").label, "SWEEP 1 OF 2")
        tap(app.buttons["hinge.next"])
        tap(app.buttons["hinge.next"])
        tap(app.buttons["hinge.holdStart"])
        XCTAssertTrue(element(app, "hinge.unavailableTitle").waitForExistence(timeout: 10))
        tap(app.buttons["hinge.finishAnyway"])

        XCTAssertEqual(element(app, "result.outcome").label, "Unavailable")
        tap(app.buttons["result.continue"])
        assertRow(app, "hingeSweep", contains: "Unavailable")
    }

    func testHingeTestIsNotApplicableWithoutHinge() throws {
        let app = launch(["-FoldMock", "nohinge"])
        tap(app.buttons["home.quick.hinge"])
        assertRow(app, "hingeSweep", contains: "Not Applicable")
    }

    // MARK: F5

    /// AC7: closed→open transitions observed in the foreground count, the page says
    /// "Folds observed by FoldCheck", and the all-time total survives a relaunch.
    func testFoldCounterCountsMockedFoldsAndPersists() throws {
        let app = launch(["-FoldMock", "closed", "-FoldDebugOverlay", "1", "-ResetFoldCounter", "1", "-UnlockReports"])
        tap(app.buttons["home.quick.foldStats"])
        XCTAssertEqual(element(app, "folds.heading").label, "Folds observed by FoldCheck")
        XCTAssertTrue(element(app, "folds.disclaimer").label.contains("not the device’s lifetime fold count"))
        waitForCount(element(app, "folds.sessionCount"), 0)

        tapDebug(app, "fold.debug")
        tapDebug(app, "fold.open")
        waitForCount(element(app, "folds.sessionCount"), 1)
        // Opening further (half → open) is not another fold.
        tapDebug(app, "fold.half")
        tapDebug(app, "fold.open")
        sleep(1)
        waitForCount(element(app, "folds.sessionCount"), 1)

        tapDebug(app, "fold.closed")
        sleep(1)
        tapDebug(app, "fold.open")
        waitForCount(element(app, "folds.sessionCount"), 2)
        waitForCount(element(app, "folds.allTimeCount"), 2)

        // Relaunch without resetting: this launch starts at 0, all time keeps 2.
        // A debounced fold is saved on the next once-a-second tick; terminate() kills the app
        // without a background transition, so give that tick time to run first.
        Thread.sleep(forTimeInterval: 1.5)
        app.terminate()
        app.launchArguments = ["-UITestMode", "1", "-FoldMock", "closed", "-UnlockReports"]
        app.launch()
        tap(app.buttons["home.quick.foldStats"])
        waitForCount(element(app, "folds.sessionCount"), 0)
        waitForCount(element(app, "folds.allTimeCount"), 2)
    }

    func testFoldStatsWithoutHinge() throws {
        let app = launch(["-FoldMock", "nohinge", "-UnlockReports"])
        tap(app.buttons["home.quick.foldStats"])
        XCTAssertTrue(element(app, "folds.notApplicable").waitForExistence(timeout: 5))
    }

    // MARK: Helpers

    /// Runs sweep, sweep, hold and returns the outcome label.
    private func runHingeTest(_ app: XCUIApplication) throws -> String {
        tap(app.buttons["home.quick.hinge"])
        tap(app.buttons["test.start"])
        try waitForReadings(app, atLeast: 150)
        tap(app.buttons["hinge.next"])
        XCTAssertTrue(app.staticTexts["SWEEP 2 OF 2"].waitForExistence(timeout: 5))
        try waitForReadings(app, atLeast: 150)
        tap(app.buttons["hinge.next"])
        tap(app.buttons["hinge.holdStart"])
        let outcome = element(app, "result.outcome")
        XCTAssertTrue(outcome.waitForExistence(timeout: 12))
        return outcome.label
    }

    private func waitForReadings(_ app: XCUIApplication, atLeast count: Int, timeout: TimeInterval = 15) throws {
        let label = element(app, "hinge.readings")
        let deadline = Date().addingTimeInterval(timeout)
        while Date() < deadline {
            if let value = Int(label.label.split(separator: " ").first ?? ""), value >= count {
                return
            }
            Thread.sleep(forTimeInterval: 0.5)
        }
        XCTFail("Readings stayed at \(label.label)")
    }

    /// The count row's accessibility label is "<title><separator><count>"; compare the number.
    private func waitForCount(_ element: XCUIElement, _ expected: Int, timeout: TimeInterval = 6, line: UInt = #line) {
        let deadline = Date().addingTimeInterval(timeout)
        while Date() < deadline {
            let digits = element.exists ? String(element.label.reversed().prefix { $0.isNumber }.reversed()) : ""
            if Int(digits) == expected { return }
            Thread.sleep(forTimeInterval: 0.3)
        }
        XCTFail("Expected \(expected), got \(element.exists ? element.label : "nothing")", line: line)
    }

    /// The fold debug overlay is attached to every presented layer, so the same identifier can
    /// appear more than once; tap the one on top.
    private func tapDebug(_ app: XCUIApplication, _ identifier: String, line: UInt = #line) {
        let deadline = Date().addingTimeInterval(5)
        while Date() < deadline {
            if let button = app.buttons.matching(identifier: identifier).allElementsBoundByIndex.first(where: { $0.isHittable }) {
                button.tap()
                return
            }
            Thread.sleep(forTimeInterval: 0.3)
        }
        XCTFail("No hittable \(identifier)", line: line)
    }

    private func launch(_ arguments: [String]) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = ["-UITestMode", "1"] + arguments
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
}
