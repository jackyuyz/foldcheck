import XCTest

/// M4 hardware tests in the simulator, which has no cameras, motion sensors, proximity
/// sensor, or haptics. Audio and Touch ID need system prompts and are left to manual runs.
@MainActor
final class HardwareUITests: XCTestCase {
    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    /// No cameras is Unavailable, without asking for camera access.
    func testCamerasUnavailableWithoutCameras() throws {
        let app = startHardwareTest("cameras")
        tap(app.buttons["test.start"])
        XCTAssertTrue(element(app, "result.outcome").waitForExistence(timeout: 10))
        XCTAssertEqual(element(app, "result.outcome").label, "Unavailable")
    }

    /// Every sensor part missing is Unavailable, never Fail.
    func testSensorsUnavailableInSimulator() throws {
        let app = startHardwareTest("sensors")
        tap(app.buttons["test.start"])
        tap(app.buttons["sensors.motionStart"])
        XCTAssertTrue(element(app, "result.outcome").waitForExistence(timeout: 15))
        XCTAssertEqual(element(app, "result.outcome").label, "Unavailable")
    }

    /// Volume presses that never arrive plus a checklist answer make Attention, with the
    /// buttons listed on the result.
    func testButtonsChecklist() throws {
        let app = startHardwareTest("buttons")
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

    /// Run the selected part directly: Duo's Touch ID changes the full plan's step count.
    private func startHardwareTest(_ component: String) -> XCUIApplication {
        XCUIDevice.shared.orientation = .portrait
        let app = XCUIApplication()
        app.launchArguments = ["-UITestMode", "1", "-FoldMock", "nohinge"]
        app.launch()
        tap(app.buttons["home.part.\(component)"])
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
