import XCTest

@MainActor
final class SimulatorGapUITests: XCTestCase {
    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    func testPartialWindowBlocksStartingATest() {
        let app = launch(extra: ["-WindowTestMode", "split"])
        app.buttons["home.quick.screen"].tap()
        XCTAssertTrue(app.staticTexts["Use full screen"].waitForExistence(timeout: 5))
        XCTAssertFalse(app.buttons["test.start"].isHittable)
    }

    func testIPadCompatibilityDisclosesWindowScope() {
        // Exercise the actual compatibility detector on iPad, and its injected state on iPhone.
        let isIPad = ProcessInfo.processInfo.environment["SIMULATOR_MODEL_IDENTIFIER"]?.hasPrefix("iPad") == true
        let app = launch(extra: isIPad ? [] : ["-WindowTestMode", "ipad"])
        app.buttons["home.quick.screen"].tap()
        XCTAssertTrue(app.descendants(matching: .any)["inspection.compatibilityWarning"].firstMatch.waitForExistence(timeout: 5))
        let screenshot = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        screenshot.name = isIPad ? "Actual-iPad-compatibility-disclosure" : "Injected-compatibility-disclosure"
        screenshot.lifetime = .keepAlways
        add(screenshot)
        app.buttons["test.start"].tap()
        XCTAssertTrue(app.buttons["pixels.next"].waitForExistence(timeout: 5))
    }

    func testAutomatedFullInspectionCreatesAPDF() {
        let app = launch(extra: ["-AutoCompleteTests", "pass", "-UnlockReports"])
        app.buttons["home.start"].tap()
        XCTAssertTrue(app.staticTexts["inspection.automatedSample"].waitForExistence(timeout: 5))
        let create = app.buttons["summary.createReport"]
        XCTAssertTrue(create.waitForExistence(timeout: 5))
        if !create.isHittable { app.swipeUp() }
        create.tap()
        XCTAssertTrue(app.descendants(matching: .any)["report.pdf"].firstMatch.waitForExistence(timeout: 15))
        XCTAssertTrue(app.buttons["report.share"].exists)
    }

    func testUnavailableReceiverCanContinueToMicrophone() {
        let app = launch(extra: [])
        app.buttons["home.start"].tap()
        for _ in 0..<3 {
            XCTAssertTrue(app.buttons["test.skip"].waitForExistence(timeout: 5))
            app.buttons["test.skip"].tap()
        }
        app.buttons["test.start"].tap()
        let springboard = XCUIApplication(bundleIdentifier: "com.apple.springboard")
        let allow = springboard.buttons["Allow"]
        if allow.waitForExistence(timeout: 3) { allow.tap() }
        for _ in 0..<2 {
            XCTAssertTrue(app.buttons["audio.playTone"].waitForExistence(timeout: 10))
            app.buttons["audio.playTone"].tap()
            app.buttons["audio.heard.yes"].tap()
        }
        let next = app.buttons["audio.receiver.unavailable.next"]
        XCTAssertTrue(next.waitForExistence(timeout: 5))
        XCTAssertFalse(app.buttons["audio.receiver.play"].exists)
        next.tap()
        XCTAssertTrue(app.buttons["audio.record"].waitForExistence(timeout: 5))
        app.buttons["test.cancel"].tap()
    }

    private func launch(extra: [String]) -> XCUIApplication {
        XCUIDevice.shared.orientation = .portrait
        let app = XCUIApplication()
        app.launchArguments = ["-UITestMode", "1", "-FoldMock", "nohinge", "-EmptyHistoryFixtures", "-foldcheck.appLanguage", "en"] + extra
        app.launch()
        XCTAssertTrue(app.buttons["home.start"].waitForExistence(timeout: 10))
        return app
    }
}
