import XCTest

@MainActor
final class FoldCheckUITests: XCTestCase {
    override func setUpWithError() throws {
        continueAfterFailure = false
    }
    
    func testLaunchWithMockHinge() throws {
        let app = XCUIApplication()
        app.launchArguments = ["-UITestMode", "1", "-FoldMock", "open"]
        app.launch()
        
        // Verify home screen loads
        XCTAssertTrue(app.staticTexts["FoldCheck"].exists)
    }
    
    func testStartInspection() throws {
        let app = XCUIApplication()
        app.launchArguments = ["-UITestMode", "1", "-FoldMock", "nohinge"]
        app.launch()
        
        // Reads "Start Inspection" with no saved inspections and "Check Again" after one.
        let startButton = app.buttons["home.start"]
        XCTAssertTrue(startButton.waitForExistence(timeout: 5))
        XCTAssertTrue(["Start Inspection", "Check Again"].contains(startButton.label), startButton.label)
    }
    
    func testNavigateToVerify() throws {
        let app = XCUIApplication()
        app.launch()
        
        // Navigate to Verify tab
        app.buttons["Verify"].firstMatch.tap()
        XCTAssertTrue(app.staticTexts["Verify a FoldCheck Report"].exists)
    }
    
    func testNavigateToSettings() throws {
        let app = XCUIApplication()
        app.launch()
        
        // Navigate to Settings tab
        app.buttons["Settings"].firstMatch.tap()
        XCTAssertTrue(app.navigationBars["Settings"].exists)
    }
}
