import XCTest

/// Takes the App Store screenshots (run by .github/workflows/appstore.yml on a 6.9-inch simulator; regular CI
/// skips it). Attachments named `appstore-NN-*` are copied into appstore/screenshots/ja/iphone69 in that order.
final class AppStoreScreenshotTests: XCTestCase {
    @MainActor
    func testTakeAppStoreScreenshots() {
        let app = XCUIApplication()
        app.launchEnvironment["HIBIMACHI_STORAGE_NAME"] = "appstore-\(UUID().uuidString)"
        app.launchEnvironment["HIBIMACHI_SEED"] = "2026"
        app.launchEnvironment["HIBIMACHI_TUTORIAL"] = "off"
        app.launchEnvironment["HIBIMACHI_DAY_PHASE"] = "day"
        app.launch()
        XCTAssertTrue(app.descendants(matching: .any)["island-view"].waitForExistence(timeout: 15))

        // 1. The island with a discovery card (the creature reacts within a minute on this seed).
        _ = app.buttons["discovery-toast"].waitForExistence(timeout: 60)
        Thread.sleep(forTimeInterval: 1)
        shoot(app, "appstore-01-island")

        // 2. Today's quests right after a "やった！".
        app.buttons["quests"].tap()
        app.buttons["goal-category-tidy"].tap()
        app.buttons["create-goal"].tap()
        XCTAssertTrue(app.buttons["quest-done-0"].waitForExistence(timeout: 5))
        app.buttons["quest-done-0"].tap()
        Thread.sleep(forTimeInterval: 1)
        shoot(app, "appstore-02-quests")
        app.buttons["閉じる"].tap()

        // 3. Placing something new.
        app.buttons["tab-nature"].tap()
        app.buttons["palette-flower"].tap()
        Thread.sleep(forTimeInterval: 1)
        shoot(app, "appstore-03-build")
        app.buttons["cancel-edit"].tap()

        // 4. The album with today's history.
        app.buttons["album"].tap()
        Thread.sleep(forTimeInterval: 1)
        shoot(app, "appstore-04-album")
        app.buttons["閉じる"].tap()

        // 5. Night, lamps lit.
        for _ in 0..<2 { app.buttons["day-phase"].tap() }  // day -> evening -> night
        Thread.sleep(forTimeInterval: 2)
        shoot(app, "appstore-05-night")
    }

    @MainActor
    private func shoot(_ app: XCUIApplication, _ name: String) {
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
