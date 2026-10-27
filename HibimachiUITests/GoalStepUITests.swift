import XCTest

/// Breaking a goal into steps (ADR-0016). On the CI simulator Apple Intelligence is usually unavailable, so the
/// category template is offered; either way the player accepts the draft and the goal shows its current step.
final class GoalStepUITests: XCTestCase {
    override func setUp() {
        continueAfterFailure = false
    }

    @MainActor
    func testAGoalCanBeBrokenIntoSteps() {
        let app = XCUIApplication()
        app.launchEnvironment["HIBIMACHI_STORAGE_NAME"] = "uitest-steps-\(UUID().uuidString)"
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
        let row = app.buttons["goal-row"].firstMatch
        XCTAssertTrue(row.waitForExistence(timeout: 5))
        row.tap()

        // The open goal card runs past the bottom of the panel on small simulators; bring its buttons up first.
        app.scrollViews.firstMatch.swipeUp()
        let plan = app.buttons["plan-goal"]
        XCTAssertTrue(plan.waitForExistence(timeout: 5))
        plan.tap()
        // AI (when available) may take a while; the template arrives at once.
        let apply = app.buttons["plan-apply"]
        XCTAssertTrue(apply.waitForExistence(timeout: 30))
        XCTAssertTrue(app.descendants(matching: .any)["plan-step-0"].firstMatch.exists)
        apply.tap()

        let summary = app.descendants(matching: .any)["step-summary"].firstMatch
        XCTAssertTrue(summary.waitForExistence(timeout: 5))
        XCTAssertTrue(summary.label.contains("ステップ 1/"), summary.label)
        XCTAssertTrue(app.descendants(matching: .any)["step-list"].firstMatch.exists)
        XCTAssertEqual(app.buttons.matching(identifier: "edit-quest").count, 3, "everyday quests stay editable")

        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = "20-goal-steps"
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
