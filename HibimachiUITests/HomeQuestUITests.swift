import XCTest

/// Today's quests on the island screen (owner feedback 2026-10-27): visible without opening a panel, done with
/// one tap, and undoable right there.
final class HomeQuestUITests: XCTestCase {
    override func setUp() {
        continueAfterFailure = false
    }

    @MainActor
    func testTodaysQuestsAreOnTheIslandScreen() {
        let app = XCUIApplication()
        app.launchEnvironment["HIBIMACHI_STORAGE_NAME"] = "uitest-home-\(UUID().uuidString)"
        app.launchEnvironment["HIBIMACHI_TUTORIAL"] = "off"
        app.launchEnvironment["HIBIMACHI_SEED"] = "2026"
        app.launchEnvironment["HIBIMACHI_AUDIO"] = "off"
        app.launchEnvironment["HIBIMACHI_DAY_PHASE"] = "day"
        app.launchArguments += ["-AppleLanguages", "(ja)", "-AppleLocale", "ja_JP"]
        app.launch()
        XCTAssertTrue(app.descendants(matching: .any)["island-view"].waitForExistence(timeout: 15))

        // No goal yet: the tray invites the player to pick one.
        let setup = app.buttons["home-quests-setup"]
        XCTAssertTrue(setup.waitForExistence(timeout: 5))
        setup.tap()
        XCTAssertTrue(app.buttons["goal-category-tidy"].waitForExistence(timeout: 10))
        app.buttons["goal-category-tidy"].tap()
        app.buttons["create-goal"].tap()
        XCTAssertTrue(app.buttons["quest-done-0"].waitForExistence(timeout: 5))
        app.buttons["panel-close"].tap()

        let done = app.buttons["home-quest-done-0"]
        XCTAssertTrue(done.waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["home-quest-start-0"].exists)
        done.tap()
        let reward = app.descendants(matching: .any)["home-reward"].firstMatch
        XCTAssertTrue(reward.waitForExistence(timeout: 5))
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = "21-home-quests"
        attachment.lifetime = .keepAlways
        add(attachment)
        app.buttons["home-undo"].tap()
        XCTAssertTrue(reward.waitForNonExistence(timeout: 5))

        // Folding keeps only the header, so the island can be seen.
        app.buttons["home-quests-toggle"].tap()
        XCTAssertTrue(app.buttons["home-quest-done-0"].waitForNonExistence(timeout: 5))
        app.buttons["home-quests-toggle"].tap()
        XCTAssertTrue(app.buttons["home-quest-done-0"].waitForExistence(timeout: 5))
    }
}
