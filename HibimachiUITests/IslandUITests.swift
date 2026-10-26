import XCTest

/// End-to-end checks on the Simulator. Each test uses its own save folder and a fixed seed.
final class IslandUITests: XCTestCase {
    private var storageName = ""

    override func setUp() {
        continueAfterFailure = false
        storageName = "uitest-\(UUID().uuidString)"
    }

    @MainActor
    private func launch(tutorial: Bool = false) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchEnvironment["HIBIMACHI_STORAGE_NAME"] = storageName
        if !tutorial { app.launchEnvironment["HIBIMACHI_TUTORIAL"] = "off" }
        app.launchEnvironment["HIBIMACHI_SEED"] = "2026"
        app.launchEnvironment["HIBIMACHI_AUDIO"] = "off"
        app.launchEnvironment["HIBIMACHI_DAY_PHASE"] = "day"
        // The assertions below read Japanese labels; English is covered by EnglishUITests.
        app.launchArguments += ["-AppleLanguages", "(ja)", "-AppleLocale", "ja_JP"]
        app.launch()
        XCTAssertTrue(app.descendants(matching: .any)["island-view"].waitForExistence(timeout: 15))
        return app
    }

    /// Opens today's quests. On a loaded CI simulator the first tap is sometimes synthesized while the app is
    /// still busy and gets lost, so wait for the panel and tap once more if it did not open.
    @MainActor
    private func openQuests(_ app: XCUIApplication) {
        let panel = app.descendants(matching: .any)["quest-panel"]
        app.buttons["quests"].tap()
        if !panel.waitForExistence(timeout: 5) { app.buttons["quests"].tap() }
        XCTAssertTrue(panel.waitForExistence(timeout: 10))
    }

    @MainActor
    private func objectCount(_ app: XCUIApplication) -> String {
        app.descendants(matching: .any)["object-count"].label
    }

    @MainActor
    private func sparkles(_ app: XCUIApplication) -> String {
        app.descendants(matching: .any)["sparkle-balance"].label
    }

    @MainActor
    private func screenshot(_ app: XCUIApplication, _ name: String) {
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }

    @MainActor
    func testPlaceUndoAndRelaunchRestoresLayout() {
        var app = launch()
        XCTAssertEqual(objectCount(app), "置いたもの 6こ")
        screenshot(app, "01-start")

        app.buttons["tab-nature"].tap()
        app.buttons["palette-flower"].tap()
        XCTAssertTrue(app.buttons["confirm-edit"].waitForExistence(timeout: 5))
        screenshot(app, "02-preview")
        app.buttons["confirm-edit"].tap()
        XCTAssertEqual(objectCount(app), "置いたもの 7こ")
        XCTAssertEqual(app.staticTexts["selection-name"].label, "はなやぶ")

        app.buttons["undo"].firstMatch.tap()
        XCTAssertEqual(objectCount(app), "置いたもの 6こ")

        // The undone flower went back to storage, so placing it again is free; then buy a bench (✨10).
        XCTAssertEqual(sparkles(app), "きらめき 25")
        app.buttons["palette-flower"].tap()
        app.buttons["confirm-edit"].tap()
        XCTAssertEqual(sparkles(app), "きらめき 25")
        app.buttons["deselect"].tap()
        app.buttons["tab-build"].tap()
        app.buttons["palette-bench"].tap()
        app.buttons["confirm-edit"].tap()
        XCTAssertEqual(objectCount(app), "置いたもの 8こ")
        XCTAssertEqual(sparkles(app), "きらめき 15")
        screenshot(app, "03-placed-bench")

        app.terminate()
        app = launch()
        XCTAssertEqual(objectCount(app), "置いたもの 8こ", "layout should be restored after relaunch")
        XCTAssertEqual(sparkles(app), "きらめき 15", "spending should be restored after relaunch")
        screenshot(app, "04-after-relaunch")
    }

    @MainActor
    func testMoveAndRemoveThroughTheAccessibleList() {
        let app = launch()
        app.buttons["object-list"].tap()
        let benchRow = app.buttons["object-row-bench"]
        XCTAssertTrue(benchRow.waitForExistence(timeout: 5))
        benchRow.tap()

        XCTAssertEqual(app.staticTexts["selection-name"].label, "ベンチ")
        app.buttons["move-selection"].tap()
        app.buttons["右上へ"].tap()
        let status = app.descendants(matching: .any)["placement-status"]
        XCTAssertTrue(status.waitForExistence(timeout: 5))
        screenshot(app, "05-moving-bench")
        XCTAssertTrue(app.buttons["confirm-edit"].isEnabled, "moving the bench one tile right is valid")
        app.buttons["confirm-edit"].tap()
        XCTAssertEqual(app.staticTexts["selection-name"].label, "ベンチ")

        app.buttons["remove-selection"].tap()
        XCTAssertEqual(objectCount(app), "置いたもの 5こ")
        app.buttons["undo"].firstMatch.tap()
        XCTAssertEqual(objectCount(app), "置いたもの 6こ")
    }

    @MainActor
    func testQuestCompletionRewardsAndCanBeUndone() {
        let app = launch()
        XCTAssertEqual(sparkles(app), "きらめき 30")
        openQuests(app)
        app.buttons["goal-category-tidy"].tap()
        XCTAssertTrue(app.buttons["create-goal"].waitForExistence(timeout: 5))
        app.buttons["create-goal"].tap()
        XCTAssertTrue(app.buttons["quest-done-0"].waitForExistence(timeout: 5))
        screenshot(app, "09-quests")
        app.buttons["quest-done-0"].tap()
        XCTAssertTrue(app.descendants(matching: .any)["reward-banner"].waitForExistence(timeout: 5))
        screenshot(app, "10-reward")
        app.buttons["閉じる"].tap()
        XCTAssertEqual(sparkles(app), "きらめき 35")
        XCTAssertEqual(app.descendants(matching: .any)["level"].label, "レベル 1")
        openQuests(app)
        app.buttons["undo-completion"].tap()
        app.buttons["閉じる"].tap()
        XCTAssertEqual(sparkles(app), "きらめき 30")
    }

    @MainActor
    func testPathPaintingAndUndo() {
        let app = launch()
        app.buttons["tab-path"].tap()
        app.buttons["palette-path"].tap()
        XCTAssertTrue(app.buttons["finish-path"].waitForExistence(timeout: 5))
        let island = app.descendants(matching: .any)["island-view"]
        // Center of the screen is the island's middle: always land on the default island.
        island.coordinate(withNormalizedOffset: CGVector(dx: 0.45, dy: 0.42)).tap()
        XCTAssertTrue(app.buttons["undo"].isEnabled, "painting a tile should be undoable")
        screenshot(app, "08-path")
        app.buttons["undo"].tap()
        XCTAssertFalse(app.buttons["undo"].isEnabled)
        app.buttons["finish-path"].tap()
        XCTAssertTrue(app.buttons["tab-path"].waitForExistence(timeout: 5))
    }

    @MainActor
    func testCreatureReactsAndDiscoveryIsRecorded() {
        let app = launch()
        let toast = app.buttons["discovery-toast"]
        XCTAssertTrue(toast.waitForExistence(timeout: 60), "the creature should react to something within a minute")
        screenshot(app, "06-discovery")
        app.buttons["field-guide"].tap()
        XCTAssertTrue(app.descendants(matching: .any)["field-guide-panel"].waitForExistence(timeout: 5))
        screenshot(app, "07-field-guide")
    }

    @MainActor
    func testWidgetPreviewShowsIslandAndTodaysQuests() {
        let app = launch()
        openQuests(app)
        app.buttons["goal-category-tidy"].tap()
        app.buttons["create-goal"].tap()
        XCTAssertTrue(app.buttons["quest-done-0"].waitForExistence(timeout: 5))
        app.buttons["quest-done-0"].tap()
        app.buttons["閉じる"].tap()
        app.buttons["メニュー"].tap()
        app.buttons["ウィジェットのプレビュー"].tap()
        let preview = app.descendants(matching: .any)["widget-preview"]
        XCTAssertTrue(preview.waitForExistence(timeout: 5))
        // Two open quests remain as "やった！" buttons; the finished one is listed as done.
        XCTAssertTrue(app.staticTexts["のこり2"].firstMatch.exists)
        screenshot(app, "11-widget-large")
        preview.swipeUp()
        screenshot(app, "12-widget-medium-small")
    }

    @MainActor
    func testTutorialGuidesThenCanBeSkippedForGood() {
        var app = launch(tutorial: true)
        let card = app.descendants(matching: .any)["tutorial-card"]
        XCTAssertTrue(card.waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["島に、ひとつ置いてみよう"].exists)
        screenshot(app, "13-tutorial")
        app.buttons["tab-nature"].tap()
        app.buttons["palette-flower"].tap()
        app.buttons["confirm-edit"].tap()
        app.buttons["deselect"].tap()
        // Placing moved the guide on (to the reaction step, or further if the creature already reacted).
        XCTAssertTrue(card.waitForExistence(timeout: 5))
        XCTAssertFalse(app.staticTexts["島に、ひとつ置いてみよう"].exists)
        app.buttons["案内をとばす"].tap()
        XCTAssertFalse(card.waitForExistence(timeout: 2))
        app.terminate()
        app = launch(tutorial: true)
        XCTAssertFalse(
            app.descendants(matching: .any)["tutorial-card"].waitForExistence(timeout: 3),
            "a skipped tutorial stays skipped")
    }

    @MainActor
    func testAlbumKeepsAndDeletesAMemory() {
        let app = launch()
        app.buttons["album"].tap()
        XCTAssertTrue(app.descendants(matching: .any)["album-panel"].waitForExistence(timeout: 5))
        XCTAssertFalse(app.buttons["save-memory"].isEnabled, "an empty memory can't be saved")
        let field = app.descendants(matching: .any)["memory-text"].firstMatch
        field.tap()
        field.typeText("first memory")
        app.buttons["save-memory"].tap()
        let row = app.descendants(matching: .any)["memory-row"]
        XCTAssertTrue(row.waitForExistence(timeout: 5))
        screenshot(app, "14-album")
        app.buttons["この記録をけす"].tap()
        app.buttons["本当にこの記録をけす"].tap()
        XCTAssertFalse(row.waitForExistence(timeout: 2))
    }

    @MainActor
    func testPlacedObjectOpensTheMemoryOfItsDayAndQuestsSuggestANextStep() {
        let app = launch()
        openQuests(app)
        app.buttons["goal-category-tidy"].tap()
        app.buttons["create-goal"].tap()
        XCTAssertTrue(app.buttons["quest-done-0"].waitForExistence(timeout: 5))
        app.buttons["quest-done-0"].tap()
        XCTAssertTrue(app.descendants(matching: .any)["next-step"].waitForExistence(timeout: 5))
        app.buttons["閉じる"].tap()

        app.buttons["tab-nature"].tap()
        app.buttons["palette-flower"].tap()
        app.buttons["confirm-edit"].tap()
        let memory = app.buttons["selection-memory"]
        XCTAssertTrue(memory.waitForExistence(timeout: 5))
        memory.tap()
        XCTAssertTrue(app.descendants(matching: .any)["memory-panel"].waitForExistence(timeout: 5))
        screenshot(app, "15-memory")
    }

    @MainActor
    func testSettingsToggleAndReplayTheGuide() {
        let app = launch()
        app.buttons["メニュー"].tap()
        app.buttons["せってい"].tap()
        XCTAssertTrue(app.descendants(matching: .any)["settings-panel"].waitForExistence(timeout: 5))
        let music = app.descendants(matching: .any)["setting-music"].firstMatch
        // The Toggle reports the system switch value (VoiceOver reads it as on/off in the user's language).
        XCTAssertEqual(music.value as? String, "1")
        music.tap()
        XCTAssertEqual(music.value as? String, "0")
        screenshot(app, "16-settings")
        app.buttons["replay-tutorial"].tap()
        XCTAssertTrue(app.descendants(matching: .any)["tutorial-card"].waitForExistence(timeout: 5))
    }
}
