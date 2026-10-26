import XCTest

/// The island picture can be shared from the menu. The system share sheet itself is not opened in tests.
final class ShareUITests: XCTestCase {
    override func setUp() {
        continueAfterFailure = false
    }

    @MainActor
    func testMenuOffersAPictureOfTheIslandToShare() {
        let app = XCUIApplication()
        app.launchEnvironment["HIBIMACHI_STORAGE_NAME"] = "uitest-share-\(UUID().uuidString)"
        app.launchEnvironment["HIBIMACHI_TUTORIAL"] = "off"
        app.launchEnvironment["HIBIMACHI_SEED"] = "2026"
        app.launchEnvironment["HIBIMACHI_AUDIO"] = "off"
        app.launchEnvironment["HIBIMACHI_DAY_PHASE"] = "day"
        app.launchArguments += ["-AppleLanguages", "(ja)", "-AppleLocale", "ja_JP"]
        app.launch()
        XCTAssertTrue(app.descendants(matching: .any)["island-view"].waitForExistence(timeout: 15))
        Thread.sleep(forTimeInterval: 1)  // let the scene draw once before taking its picture
        app.buttons["メニュー"].tap()
        app.buttons["島の絵をシェア"].tap()
        XCTAssertTrue(app.descendants(matching: .any)["share-panel"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.descendants(matching: .any)["share-island-link"].firstMatch.exists, "a picture was made")
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = "18-share"
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
