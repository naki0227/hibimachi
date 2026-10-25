import XCTest

final class LaunchUITests: XCTestCase {
    @MainActor
    func testAppLaunchesAndShowsIsland() {
        let app = XCUIApplication()
        app.launch()
        XCTAssertTrue(app.otherElements["island-view"].waitForExistence(timeout: 10))
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = "launch"
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
