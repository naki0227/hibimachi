import XCTest

/// Scripted ~2 minute play-through used only to record a demo video (.github/workflows/demo-video.yml).
/// Regular CI skips it (`-skip-testing:HibimachiUITests/DemoUITests`); it asserts little on purpose.
final class DemoUITests: XCTestCase {
    @MainActor
    func testRecordDemo() {
        let app = XCUIApplication()
        app.launchEnvironment["HIBIMACHI_STORAGE_NAME"] = "demo-\(UUID().uuidString)"
        app.launchEnvironment["HIBIMACHI_SEED"] = "2026"
        app.launch()
        XCTAssertTrue(app.descendants(matching: .any)["island-view"].waitForExistence(timeout: 15))

        // 1. Watch the creature wander; the first discovery usually appears within seconds.
        pause(8)

        // 2. Zoom in and back out.
        app.descendants(matching: .any)["island-view"].pinch(withScale: 1.8, velocity: 1)
        pause(4)
        app.buttons["メニュー"].tap()
        app.buttons["島全体を表示"].tap()
        pause(2)

        // 3. Put a flower right next to the bench → the creature's reaction changes ("bloom-bench").
        app.buttons["palette-flower"].tap()
        pause(1.5)
        tile(app, x: 11, y: 9).tap()
        pause(1.5)
        app.buttons["confirm-edit"].tap()
        let bloom = app.buttons["発見！ 花をながめて休む"]
        _ = bloom.waitForExistence(timeout: 90)
        pause(6)

        // 4. Move the house by dragging its ghost.
        tile(app, x: 3, y: 11).tap()
        pause(1)
        app.buttons["move-selection"].tap()
        pause(1)
        tile(app, x: 4, y: 12).press(forDuration: 0.3, thenDragTo: tile(app, x: 6, y: 14))
        pause(1.5)
        app.buttons["confirm-edit"].tap()
        pause(3)

        // 5. Put a tree away, then undo.
        tile(app, x: 11, y: 12).tap()
        pause(1)
        app.buttons["remove-selection"].tap()
        pause(2)
        app.buttons["undo"].firstMatch.tap()
        pause(3)

        // 6. Invalid spot: a pond on the water shows the reason and cannot be confirmed.
        app.buttons["palette-pond"].tap()
        pause(1)
        tile(app, x: 0, y: 0).tap()
        pause(3)
        app.buttons["cancel-edit"].tap()
        pause(2)

        // 7. Field guide, then a last look at the island.
        app.buttons["field-guide"].tap()
        pause(4)
        app.buttons["閉じる"].tap()
        pause(8)
    }

    /// Screen point of a tile's center. Mirrors IslandScene.resetCamera: the 16x16 map (512pt + 48pt margins)
    /// is fitted to the window and centered.
    @MainActor
    private func tile(_ app: XCUIApplication, x: Int, y: Int) -> XCUICoordinate {
        let frame = app.windows.firstMatch.frame
        let scale = min(max(608 / frame.width, 608 / frame.height), 2.0)
        let size = 32 / scale
        let left = frame.width / 2 - 8 * size
        let top = frame.height / 2 - 8 * size
        let point = CGVector(dx: left + (CGFloat(x) + 0.5) * size, dy: top + (CGFloat(15 - y) + 0.5) * size)
        return app.coordinate(withNormalizedOffset: .zero).withOffset(point)
    }

    private func pause(_ seconds: TimeInterval) {
        Thread.sleep(forTimeInterval: seconds)
    }
}
