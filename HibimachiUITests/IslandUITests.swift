import XCTest

/// End-to-end checks on the Simulator. Each test uses its own save folder and a fixed seed.
final class IslandUITests: XCTestCase {
    private var storageName = ""

    override func setUp() {
        continueAfterFailure = false
        storageName = "uitest-\(UUID().uuidString)"
    }

    @MainActor
    private func launch() -> XCUIApplication {
        let app = XCUIApplication()
        app.launchEnvironment["HIBIMACHI_STORAGE_NAME"] = storageName
        app.launchEnvironment["HIBIMACHI_SEED"] = "2026"
        app.launch()
        XCTAssertTrue(app.descendants(matching: .any)["island-view"].waitForExistence(timeout: 15))
        return app
    }

    @MainActor
    private func objectCount(_ app: XCUIApplication) -> String {
        app.descendants(matching: .any)["object-count"].label
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

        app.buttons["tab-build"].tap()
        app.buttons["palette-house-small"].tap()
        app.buttons["confirm-edit"].tap()
        XCTAssertEqual(objectCount(app), "置いたもの 7こ")
        screenshot(app, "03-placed-house")

        app.terminate()
        app = launch()
        XCTAssertEqual(objectCount(app), "置いたもの 7こ", "layout should be restored after relaunch")
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
        XCTAssertTrue(app.navigationBars["図鑑"].waitForExistence(timeout: 5))
        screenshot(app, "07-field-guide")
    }
}
