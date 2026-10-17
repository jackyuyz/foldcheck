import XCTest

/// M6, AC8: every test is free; reports, history and compare, and fold stats need the
/// purchase. `-UnlockReports` (DEBUG only) stands in for a purchase where a test needs it.
@MainActor
final class StoreUITests: XCTestCase {
    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    func testFreeUserCanTestButPaidFeaturesShowThePaywall() throws {
        let app = launch(unlocked: false)
        finishScreenTest(app, save: true)

        tap(app.buttons["summary.createReport"])
        XCTAssertTrue(app.buttons["paywall.purchase"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["paywall.restore"].exists)
        tap(app.buttons["paywall.close"])

        tap(app.buttons["inspection.close"])
        tap(app.buttons["home.quick.foldStats"])
        XCTAssertTrue(app.buttons["paywall.purchase"].waitForExistence(timeout: 5))
        tap(app.buttons["paywall.close"])

        // The saved session stays on the device, behind the lock.
        tap(app.buttons["History"].firstMatch)
        XCTAssertTrue(element(app, "history.locked").waitForExistence(timeout: 5))
        XCTAssertFalse(app.buttons["history.row"].exists)
        tap(app.buttons["history.unlock"])
        XCTAssertTrue(app.buttons["paywall.purchase"].waitForExistence(timeout: 5))
    }

    func testCompareTwoSavedInspections() throws {
        let app = launch(unlocked: true)
        finishScreenTest(app, save: true)
        tap(app.buttons["inspection.close"])
        finishScreenTest(app, save: true)
        tap(app.buttons["inspection.close"])

        tap(app.buttons["History"].firstMatch)
        tap(app.buttons["history.compare"])
        let rows = app.buttons.matching(identifier: "history.row")
        XCTAssertGreaterThanOrEqual(rows.count, 2)
        rows.element(boundBy: 0).tap()
        rows.element(boundBy: 1).tap()
        tap(app.buttons["history.compareSelected"])

        XCTAssertTrue(element(app, "compare.score").waitForExistence(timeout: 5))
        XCTAssertTrue(element(app, "compare.row.pixels").exists)
        tap(app.buttons["compare.done"])

        // Outside compare mode a row opens that inspection.
        tap(app.buttons["history.compare"])
        app.buttons.matching(identifier: "history.row").element(boundBy: 0).tap()
        XCTAssertTrue(app.buttons["history.detail.done"].waitForExistence(timeout: 5))
    }

    // MARK: Helpers

    private func launch(unlocked: Bool) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = ["-UITestMode", "1", "-FoldMock", "nohinge"] + (unlocked ? ["-UnlockReports"] : [])
        app.launch()
        return app
    }

    /// Runs the quick screen test to its summary, optionally saving it to History.
    private func finishScreenTest(_ app: XCUIApplication, save: Bool) {
        tap(app.buttons["home.quick.screen"])
        tap(app.buttons["test.start"])
        for _ in 0..<6 {
            tap(app.buttons["pixels.next"])
        }
        tap(app.buttons["result.continue"])
        if save {
            tap(app.buttons["summary.save"])
        }
    }

    private func element(_ app: XCUIApplication, _ identifier: String) -> XCUIElement {
        app.descendants(matching: .any)[identifier].firstMatch
    }

    private func tap(_ element: XCUIElement, file: StaticString = #filePath, line: UInt = #line) {
        XCTAssertTrue(element.waitForExistence(timeout: 5), "Missing \(element)", file: file, line: line)
        element.tap()
    }
}
