import XCTest

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
        
        // Tap start inspection
        let startButton = app.buttons["Start Inspection"]
        XCTAssertTrue(startButton.exists)
    }
    
    func testNavigateToVerify() throws {
        let app = XCUIApplication()
        app.launch()
        
        // Navigate to Verify tab
        app.tabBars.buttons["Verify"].tap()
        XCTAssertTrue(app.staticTexts["Verify a FoldCheck Report"].exists)
    }
    
    func testNavigateToSettings() throws {
        let app = XCUIApplication()
        app.launch()
        
        // Navigate to Settings tab
        app.tabBars.buttons["Settings"].tap()
        XCTAssertTrue(app.navigationBars["Settings"].exists)
    }
}
