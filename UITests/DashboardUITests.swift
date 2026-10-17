import XCTest

/// Design A dashboard, with the isolated sample data from -ScreenshotFixtures (two full
/// inspections; the newer one has the hinge at Attention, hardware tests skipped).
@MainActor
final class DashboardUITests: XCTestCase {
    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    func testDashboardShowsScoreAndEachPart() throws {
        let app = XCUIApplication()
        app.launchArguments = ["-UITestMode", "1", "-FoldMock", "open", "-ScreenshotFixtures"]
        app.launch()

        let score = element(app, "home.health.score")
        XCTAssertTrue(score.waitForExistence(timeout: 5))
        XCTAssertEqual(score.value as? String, "92 out of 100")
        XCTAssertEqual(element(app, "home.health.summary").label, "1 part needs attention")
        XCTAssertEqual(element(app, "home.health.coverage").label, "Checked 4 of 9 parts")
        XCTAssertEqual(app.buttons["home.start"].label, "Check Again")

        let hinge = app.buttons["home.quick.hinge"]
        XCTAssertTrue(hinge.label.contains("Attention"), hinge.label)
        XCTAssertTrue(hinge.label.contains("Max Gap"), hinge.label)
        let buttons = app.buttons["home.part.buttons"]
        if !buttons.exists { app.swipeUp() }
        XCTAssertTrue(buttons.label.contains("Not run"), buttons.label)

        // A tile runs that part's test.
        hinge.tap()
        XCTAssertTrue(app.staticTexts["Test 1 of 1"].waitForExistence(timeout: 5))
    }

    func testEmptyDashboardUsesIsolatedHistory() throws {
        let app = XCUIApplication()
        app.launchArguments = ["-UITestMode", "1", "-FoldMock", "open", "-EmptyHistoryFixtures"]
        app.launch()
        XCTAssertTrue(element(app, "home.health.empty").waitForExistence(timeout: 5))
        XCTAssertEqual(app.buttons["home.start"].label, "Start Inspection")
        XCTAssertFalse(element(app, "home.health.coverage").exists)
        XCTAssertFalse(element(app, "home.lastInspection").exists)
        XCTAssertTrue(app.buttons["home.quick.hinge"].label.contains("Not run"))
    }

    func testDashboardAtLargestAccessibilityText() throws {
        let app = XCUIApplication()
        app.launchArguments = ["-UITestMode", "1", "-FoldMock", "open", "-ScreenshotFixtures",
                               "-UIPreferredContentSizeCategoryName", "UICTContentSizeCategoryAccessibilityXXXL"]
        app.launch()
        let score = element(app, "home.health.score")
        XCTAssertTrue(score.waitForExistence(timeout: 5))
        XCTAssertEqual(score.value as? String, "92 out of 100")
        // At accessibility sizes the caption is outside the 168 pt ring, so the combined
        // accessibility element must include that extra height.
        XCTAssertGreaterThan(score.frame.height, 190)
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = "dashboard-accessibility-caption-outside-ring"
        attachment.lifetime = .keepAlways
        add(attachment)
    }

    private func element(_ app: XCUIApplication, _ identifier: String) -> XCUIElement {
        app.descendants(matching: .any)[identifier].firstMatch
    }
}
