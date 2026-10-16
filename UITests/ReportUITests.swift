import XCTest

/// M5: from a finished test to a signed PDF. The simulator on Apple silicon has a Secure
/// Enclave, so the report is signed with a real key and shows no development banner.
final class ReportUITests: XCTestCase {
    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    func testCreateReportShowsSignedPDF() throws {
        let app = XCUIApplication()
        app.launchArguments = ["-UITestMode", "1", "-FoldMock", "nohinge"]
        app.launch()

        tap(app.buttons["home.quick.screen"])
        tap(app.buttons["test.start"])
        for _ in 0..<6 {
            tap(app.buttons["pixels.next"])
        }
        tap(app.buttons["result.continue"])
        tap(app.buttons["summary.createReport"])

        XCTAssertTrue(element(app, "report.pdf").waitForExistence(timeout: 15))
        XCTAssertTrue(element(app, "report.share").exists)
        tap(app.buttons["report.close"])
        XCTAssertTrue(app.buttons["summary.createReport"].waitForExistence(timeout: 5))
    }

    private func element(_ app: XCUIApplication, _ identifier: String) -> XCUIElement {
        app.descendants(matching: .any)[identifier].firstMatch
    }

    private func tap(_ element: XCUIElement, file: StaticString = #filePath, line: UInt = #line) {
        XCTAssertTrue(element.waitForExistence(timeout: 5), "Missing \(element)", file: file, line: line)
        element.tap()
    }
}
