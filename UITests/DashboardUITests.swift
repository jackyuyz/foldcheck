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
        let totalParts = app.buttons["home.part.touchID"].exists ? 9 : 8
        XCTAssertEqual(element(app, "home.health.coverage").label, "Checked 4 of \(totalParts) parts")
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

    func testSplitOverviewStaysPutWhilePartsScroll() throws {
        // Empty history gives a genuinely fitting overview, including its bottom padding.
        // A saved English overview can overflow slightly even though History is hittable.
        let app = launchForScrolling(emptyHistory: true)
        let (overview, parts) = try splitScrollViews(app)
        let score = element(app, "home.health.score")
        XCTAssertTrue(element(app, "home.health.empty").exists)
        XCTAssertTrue(app.buttons["home.start"].isHittable)
        let origin = score.frame.minY
        overview.swipeUp()
        XCTAssertEqual(score.frame.minY, origin, accuracy: 1)
        parts.swipeUp()
        XCTAssertTrue(app.buttons["home.part.buttons"].isHittable)
        // The shared navigation title may collapse on the first right-column scroll.
        // Once it has, further scrolling must not change the overview's position.
        let settledOrigin = score.frame.minY
        parts.swipeUp()
        XCTAssertEqual(score.frame.minY, settledOrigin, accuracy: 1)
        overview.swipeUp()
        XCTAssertEqual(score.frame.minY, settledOrigin, accuracy: 1)
    }

    func testOverflowingSplitOverviewCanReachHistory() throws {
        let app = launchForScrolling(largeText: true)
        let (overview, parts) = try splitScrollViews(app)
        let score = element(app, "home.health.score")
        let scoreOrigin = score.frame.minY
        let partsOrigin = parts.frame
        let hingeOrigin = app.buttons["home.quick.hinge"].frame.minY
        let history = app.buttons["home.lastInspection"]
        XCTAssertFalse(history.isHittable, "Large text must overflow this viewport")
        for _ in 0..<6 {
            if history.isHittable { break }
            overview.swipeUp()
        }
        XCTAssertTrue(history.isHittable)
        XCTAssertLessThan(score.frame.minY, scoreOrigin)
        XCTAssertEqual(parts.frame, partsOrigin)
        XCTAssertEqual(app.buttons["home.quick.hinge"].frame.minY, hingeOrigin, accuracy: 1)
    }

    func testStackedDashboardStillScrollsToParts() throws {
        let app = launchForScrolling()
        try XCTSkipUnless(element(app, "layout.stacked").exists, "Requires a single-column display")
        let score = element(app, "home.health.score")
        let origin = score.frame.minY
        let buttons = app.buttons["home.part.buttons"]
        for _ in 0..<6 {
            if buttons.isHittable { break }
            app.swipeUp()
        }
        XCTAssertTrue(buttons.isHittable)
        XCTAssertLessThan(score.frame.minY, origin)
    }

    private func launchForScrolling(largeText: Bool = false, emptyHistory: Bool = false) -> XCUIApplication {
        if XCUIScreen.screens.count == 1 { XCUIDevice.shared.orientation = .portrait }
        let app = XCUIApplication()
        app.launchArguments = ["-UITestMode", "1", "-FoldMock", "open",
                               emptyHistory ? "-EmptyHistoryFixtures" : "-ScreenshotFixtures",
                               "-foldcheck.appLanguage", "en"]
        if largeText {
            app.launchArguments += ["-UIPreferredContentSizeCategoryName", "UICTContentSizeCategoryAccessibilityXXXL"]
        }
        app.launch()
        XCTAssertTrue(element(app, "home.health.score").waitForExistence(timeout: 5))
        return app
    }

    private func splitScrollViews(_ app: XCUIApplication) throws -> (XCUIElement, XCUIElement) {
        let overview = app.scrollViews.containing(.button, identifier: "home.start").firstMatch
        let parts = app.scrollViews.containing(.button, identifier: "home.quick.hinge").firstMatch
        try XCTSkipUnless(parts.frame.minX > overview.frame.midX, "Requires a two-column inner display")
        return (overview, parts)
    }

    private func element(_ app: XCUIApplication, _ identifier: String) -> XCUIElement {
        app.descendants(matching: .any)[identifier].firstMatch
    }
}
