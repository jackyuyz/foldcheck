import XCTest

/// M7: exercise real input, honest accessibility skips and localized PDF previews.
@MainActor
final class PolishUITests: XCTestCase {
    override func setUpWithError() throws { continueAfterFailure = false }

    func testToolbarGaugeStartsHingeCheck() throws {
        let app = launch()
        tap(app.buttons["hingeAngle.button"])
        tap(app.buttons["hingeAngle.runHingeCheck"])
        tap(app.buttons["test.start"])
        XCTAssertTrue(element(app, "hinge.chart").waitForExistence(timeout: 5))
    }

    func testTouchGridRotatesAndPreservesCoverage() throws {
        try XCTSkipIf(XCUIScreen.screens.count > 1,
                      "Duo RC does not rotate its inner panel through XCUIDevice.orientation; verify with Device Hub. Run this regression on a single-screen iPhone with FoldMock.")
        XCUIDevice.shared.orientation = .landscapeLeft
        defer { XCUIDevice.shared.orientation = .portrait }  // later tests expect portrait
        let app = launch(extra: ["-touchTapMode", "NO"])
        tap(app.buttons["home.quick.touch"])
        tap(app.buttons["test.start"])
        let canvas = element(app, "touchGrid.canvas")
        XCTAssertTrue(canvas.waitForExistence(timeout: 5))
        let initialTotal = try totalCells(canvas)
        let initialPoint = CGVector(dx: 0.23, dy: 0.31)
        canvas.coordinate(withNormalizedOffset: initialPoint).tap()
        XCTAssertEqual(try covered(canvas), 1)
        // Compare actual canvas geometry with its baseline rather than assuming
        // a fixed orientation at launch.
        let initialLandscape = canvas.frame.width > canvas.frame.height
        let orientations: [UIDeviceOrientation] = [.landscapeLeft, .portrait, .landscapeRight, .landscapeLeft]
        // Interface orientations rotate opposite to UIDevice's landscape names.
        let samePhysicalPoints = [initialPoint, CGVector(dx: 0.69, dy: 0.23),
                                  CGVector(dx: 0.77, dy: 0.69), initialPoint]
        for (index, orientation) in orientations.enumerated() {
            XCUIDevice.shared.orientation = orientation
            let landscape = orientation == .portrait ? !initialLandscape : initialLandscape
            let rotated = XCTNSPredicateExpectation(predicate: NSPredicate { _, _ in
                (canvas.frame.width > canvas.frame.height) == landscape
            }, object: nil)
            XCTAssertEqual(XCTWaiter.wait(for: [rotated], timeout: 10), .completed, "Canvas: \(canvas.frame)")
            XCTAssertEqual(try covered(canvas), 1, "Rotation must preserve tested cells")
            XCTAssertEqual(try totalCells(canvas), initialTotal, "The chosen grid must stay fixed")
            canvas.coordinate(withNormalizedOffset: samePhysicalPoints[index]).tap()
            XCTAssertEqual(try covered(canvas), 1, "The same physical cell must stay the same cell")
            capture("touch-preserved-\(index)")
        }
        canvas.coordinate(withNormalizedOffset: CGVector(dx: 0.7, dy: 0.6)).tap()
        XCTAssertEqual(try covered(canvas), 2, "New contacts must continue adding coverage")
    }

    func testTapModeCountsOnlyContactBeginnings() throws {
        let app = launch()
        tap(app.buttons["home.quick.touch"])
        let toggle = app.switches["test.tapMode"]
        XCTAssertTrue(toggle.waitForExistence(timeout: 5))
        if toggle.value as? String != "1" { toggle.tap() }
        tap(app.buttons["test.start"])
        let canvas = element(app, "touchGrid.canvas")
        XCTAssertTrue(canvas.waitForExistence(timeout: 5))
        let start = canvas.coordinate(withNormalizedOffset: CGVector(dx: 0.3, dy: 0.4))
        start.press(forDuration: 0.1, thenDragTo: canvas.coordinate(withNormalizedOffset: CGVector(dx: 0.7, dy: 0.4)))
        XCTAssertEqual(try covered(canvas), 1, "A drag in tap mode must not fill a path")
        canvas.coordinate(withNormalizedOffset: CGVector(dx: 0.7, dy: 0.6)).tap()
        XCTAssertEqual(try covered(canvas), 2)
        tap(app.buttons["touchGrid.finish"])
        tap(app.buttons["touchGrid.blockedByCase"])
        tap(app.buttons["touchGrid.multiDone"])
        XCTAssertTrue(element(app, "result.systemNotes").label.contains("physical taps"))
    }

    func testVisualSkipPreservesReasonInChineseReport() throws {
        let app = launch(language: "zh-Hans")
        tap(app.buttons["home.quick.screen"])
        tap(app.buttons["test.skipSighted"])
        let row = element(app, "summary.row.pixels")
        XCTAssertTrue(row.waitForExistence(timeout: 5))
        XCTAssertTrue(row.label.contains("视觉协助"), row.label)
        XCTAssertTrue(row.label.contains("跳过"), row.label)
        tap(app.buttons["summary.createReport"])
        XCTAssertTrue(element(app, "report.pdf").waitForExistence(timeout: 20))
        capture("zh-Hans-accessibility-report")
    }

    func testAccessibilityTextKeepsActionsReachable() throws {
        let app = launch(extra: ["-UIPreferredContentSizeCategoryName", "UICTContentSizeCategoryAccessibilityXXXL"])
        tap(app.buttons["home.start"])
        let skip = app.buttons["test.skipSighted"]
        reveal(skip, in: app)
        tap(skip)
        let next = app.buttons["test.start"]
        reveal(next, in: app)
        XCTAssertTrue(next.isHittable, app.debugDescription)
        capture("en-accessibility-text")
    }

    /// Actual app screenshots, with explicitly labeled sample sessions in an isolated store.
    func testCaptureDuoReviewScreens() throws {
        for language in ["en", "zh-Hans"] {
            let app = launch(language: language)
            XCTAssertTrue(app.buttons["home.start"].waitForExistence(timeout: 5))
            capture("\(language)-01-home")
            tap(app.buttons["home.lastInspection"])
            XCTAssertTrue(app.buttons["summary.createReport"].waitForExistence(timeout: 5))
            capture("\(language)-02-summary")
            tap(app.buttons["summary.createReport"])
            XCTAssertTrue(element(app, "report.pdf").waitForExistence(timeout: 20))
            capture("\(language)-03-report")
            app.terminate()

            app.launch()
            tap(app.buttons[language == "en" ? "History" : "记录"].firstMatch)
            tap(app.buttons["history.compare"])
            let rows = app.buttons.matching(identifier: "history.row")
            XCTAssertEqual(rows.count, 2)
            rows.element(boundBy: 0).tap()
            rows.element(boundBy: 1).tap()
            tap(app.buttons["history.compareSelected"])
            XCTAssertTrue(element(app, "compare.score").waitForExistence(timeout: 5))
            capture("\(language)-04-compare")
            app.terminate()

            app.launch()
            tap(app.buttons["home.quick.touch"])
            let toggle = app.switches["test.tapMode"]
            if toggle.value as? String == "1" { toggle.tap() }
            tap(app.buttons["test.start"])
            let canvas = element(app, "touchGrid.canvas")
            XCTAssertTrue(canvas.waitForExistence(timeout: 5))
            canvas.coordinate(withNormalizedOffset: CGVector(dx: 0.2, dy: 0.3))
                .press(forDuration: 0.1, thenDragTo: canvas.coordinate(withNormalizedOffset: CGVector(dx: 0.8, dy: 0.6)))
            capture("\(language)-05-touch")
            app.terminate()

            app.launch()
            tap(app.buttons["home.quick.hinge"])
            tap(app.buttons["test.start"])
            XCTAssertTrue(element(app, "hinge.chart").waitForExistence(timeout: 5))
            // Wait on an observable reading count instead of a fixed delay.
            let readings = element(app, "hinge.readings")
            let sampled = XCTNSPredicateExpectation(
                predicate: NSPredicate(format: "label MATCHES %@", ".*[2-9][0-9].*"), object: readings)
            XCTAssertEqual(XCTWaiter.wait(for: [sampled], timeout: 12), .completed)
            capture("\(language)-06-hinge")
            app.terminate()
        }
    }

    private func launch(language: String = "en", extra: [String] = []) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = ["-UITestMode", "1", "-FoldMock", "sweep:20-178:6", "-UnlockReports", "-ScreenshotFixtures",
                               "-foldcheck.appLanguage", language, "-foldcheck.reportUsesEnglish", "NO"] + extra
        app.launch()
        return app
    }

    private func covered(_ canvas: XCUIElement) throws -> Int {
        let value = try XCTUnwrap(canvas.value as? String)
        return try XCTUnwrap(value.split(whereSeparator: { !$0.isNumber }).first.flatMap { Int($0) })
    }

    private func totalCells(_ canvas: XCUIElement) throws -> Int {
        let value = try XCTUnwrap(canvas.value as? String)
        let numbers = value.split(whereSeparator: { !$0.isNumber }).compactMap { Int($0) }
        XCTAssertGreaterThanOrEqual(numbers.count, 2)
        return numbers[1]
    }

    private func element(_ app: XCUIApplication, _ identifier: String) -> XCUIElement {
        app.descendants(matching: .any)[identifier].firstMatch
    }

    private func reveal(_ element: XCUIElement, in app: XCUIApplication) {
        for _ in 0..<8 {
            if element.isHittable { return }
            // Target the presented scroll view, not Home's scroll view behind the cover.
            app.scrollViews.element(boundBy: app.scrollViews.count - 1).swipeUp()
        }
    }

    private func tap(_ element: XCUIElement, file: StaticString = #filePath, line: UInt = #line) {
        XCTAssertTrue(element.waitForExistence(timeout: 5), "Missing \(element)", file: file, line: line)
        element.tap()
    }

    private func capture(_ name: String) {
        // Duo has an independent cover and inner display. Preserve every active screen;
        // XCUIScreen.main alone can capture an inactive/black cover while Duo is open.
        for (index, screen) in XCUIScreen.screens.enumerated() {
            let attachment = XCTAttachment(screenshot: screen.screenshot())
            attachment.name = "M7-\(name)-screen-\(index)"
            attachment.lifetime = .keepAlways
            add(attachment)
        }
    }
}
