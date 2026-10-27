import XCTest

/// "今からやる → おわった" with a record that fits the quest (ADR-0015). Photos are not taken in tests (the
/// simulator has no camera), so the tidy quest is completed with a few words, which also counts.
final class TaskSessionUITests: XCTestCase {
    override func setUp() {
        continueAfterFailure = false
    }

    @MainActor
    func testStartingAndFinishingAQuestKeepsItsRecord() {
        let app = XCUIApplication()
        app.launchEnvironment["HIBIMACHI_STORAGE_NAME"] = "uitest-session-\(UUID().uuidString)"
        app.launchEnvironment["HIBIMACHI_TUTORIAL"] = "off"
        app.launchEnvironment["HIBIMACHI_SEED"] = "2026"
        app.launchEnvironment["HIBIMACHI_AUDIO"] = "off"
        app.launchEnvironment["HIBIMACHI_DAY_PHASE"] = "day"
        app.launchArguments += ["-AppleLanguages", "(ja)", "-AppleLocale", "ja_JP"]
        app.launch()
        XCTAssertTrue(app.descendants(matching: .any)["island-view"].waitForExistence(timeout: 15))

        app.buttons["quests"].tap()
        XCTAssertTrue(app.buttons["goal-category-tidy"].waitForExistence(timeout: 10))
        app.buttons["goal-category-tidy"].tap()
        app.buttons["create-goal"].tap()
        XCTAssertTrue(app.buttons["quest-start-0"].waitForExistence(timeout: 5))
        app.buttons["quest-start-0"].tap()
        XCTAssertTrue(app.descendants(matching: .any)["session-card"].waitForExistence(timeout: 5))
        XCTAssertFalse(app.buttons["quest-start-1"].exists, "one quest at a time")

        // Leaving the panel keeps the session; the island shows it and brings the panel back.
        app.buttons["panel-close"].tap()
        let chip = app.buttons["session-chip"]
        XCTAssertTrue(chip.waitForExistence(timeout: 5))
        chip.tap()

        app.buttons["session-finish"].tap()
        let note = app.descendants(matching: .any)["finish-note"].firstMatch
        XCTAssertTrue(note.waitForExistence(timeout: 5))
        note.tap()
        // ASCII: typed Japanese can stay as uncommitted (marked) text on the simulator's keyboard.
        note.typeText("desk")
        let complete = app.descendants(matching: .any).matching(NSPredicate(format: "label CONTAINS %@", "そろいました"))
        XCTAssertTrue(complete.firstMatch.waitForExistence(timeout: 5))
        app.buttons["session-done"].tap()
        XCTAssertTrue(app.descendants(matching: .any)["finished-task"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.descendants(matching: .any)["record-bonus"].exists)
        XCTAssertFalse(app.descendants(matching: .any)["session-card"].exists)

        // Sharing the record: the card is rendered for the chosen parts, photos left out by default.
        app.buttons["finished-share"].tap()
        XCTAssertTrue(app.descendants(matching: .any)["share-record-link"].firstMatch.waitForExistence(timeout: 5))
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = "19-task-finished"
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
