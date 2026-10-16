import XCTest

/// M4 hardware tests in the simulator, which has no cameras, motion sensors, proximity
/// sensor, or haptics. Audio and Touch ID need system prompts and are left to manual runs.
final class HardwareUITests: XCTestCase {
    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    /// No cameras is Unavailable, without asking for camera access.
    func testCamerasUnavailableWithoutCameras() throws {
        let app = startFullInspection(skipping: 2)
        XCTAssertTrue(app.staticTexts["Test 3 of 6"].waitForExistence(timeout: 5))
        tap(app.buttons["test.start"])
        XCTAssertTrue(element(app, "result.outcome").waitForExistence(timeout: 10))
        XCTAssertEqual(element(app, "result.outcome").label, "Unavailable")
    }

    /// Every sensor part missing is Unavailable, never Fail.
    func testSensorsUnavailableInSimulator() throws {
        let app = startFullInspection(skipping: 4)
        XCTAssertTrue(app.staticTexts["Test 5 of 6"].waitForExistence(timeout: 5))
        tap(app.buttons["test.start"])
        tap(app.buttons["sensors.motionStart"])
        XCTAssertTrue(element(app, "result.outcome").waitForExistence(timeout: 15))
        XCTAssertEqual(element(app, "result.outcome").label, "Unavailable")
    }

    /// Volume presses that never arrive plus a checklist answer make Attention, with the
    /// buttons listed on the result.
    func testButtonsChecklist() throws {
        let app = startFullInspection(skipping: 5)
        XCTAssertTrue(app.staticTexts["Test 6 of 6"].waitForExistence(timeout: 5))
        tap(app.buttons["test.start"])
        tap(app.buttons["buttons.volumeNotWorking"])
        tap(app.buttons["buttons.volumeNotWorking"])

        tap(app.segmentedControls["buttons.answer.side"].buttons["Works"])
        tap(app.segmentedControls["buttons.answer.action"].buttons["Doesn’t work"])
        tap(app.segmentedControls["buttons.answer.cameraControl"].buttons["Not on this iPhone"])
        tap(app.buttons["buttons.finish"])

        XCTAssertEqual(element(app, "result.outcome").label, "Attention")
        let notes = element(app, "result.systemNotes").label
        XCTAssertTrue(notes.contains("Not detected: Volume up and Volume down"), notes)
        XCTAssertTrue(notes.contains("Reported not working: Action button"), notes)
    }

    // MARK: Helpers

    /// Full inspection on a device without a hinge, skipping the first `count` tests.
    private func startFullInspection(skipping count: Int) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = ["-UITestMode", "1", "-FoldMock", "nohinge"]
        app.launch()
        tap(app.buttons["home.start"])
        for _ in 0..<count {
            tap(app.buttons["test.skip"])
        }
        return app
    }

    private func element(_ app: XCUIApplication, _ identifier: String) -> XCUIElement {
        app.descendants(matching: .any)[identifier].firstMatch
    }

    private func tap(_ element: XCUIElement, file: StaticString = #filePath, line: UInt = #line) {
        XCTAssertTrue(element.waitForExistence(timeout: 5), "Missing \(element)", file: file, line: line)
        element.tap()
    }
}
