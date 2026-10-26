import XCTest

/// Scripted ~2.5 minute play-through used only to record a demo video (.github/workflows/demo-video.yml).
/// Regular CI skips it (`-skip-testing:HibimachiUITests/DemoUITests`); it asserts little on purpose.
final class DemoUITests: XCTestCase {
    @MainActor
    func testRecordDemo() {
        let app = XCUIApplication()
        app.launchEnvironment["HIBIMACHI_STORAGE_NAME"] = "demo-\(UUID().uuidString)"
        app.launchEnvironment["HIBIMACHI_SEED"] = "2026"
        app.launchEnvironment["HIBIMACHI_DAY_PHASE"] = "day"
        app.launch()
        XCTAssertTrue(app.descendants(matching: .any)["island-view"].waitForExistence(timeout: 15))

        // 1. Watch the island and the creature; the first discovery usually appears within seconds.
        pause(8)

        // 2. Zoom in, then back to the whole island.
        app.descendants(matching: .any)["island-view"].pinch(withScale: 2.0, velocity: 1)
        pause(4)
        app.buttons["メニュー"].tap()
        app.buttons["島全体を表示"].tap()
        pause(2)

        // 3. A flower bush right next to the bench changes the creature's reaction ("bloom-bench").
        app.buttons["tab-nature"].tap()
        pause(1)
        app.buttons["palette-flower"].tap()
        pause(1.5)
        tile(app, x: 11, y: 9).tap()
        pause(1.5)
        app.buttons["confirm-edit"].tap()
        app.buttons["deselect"].tap()
        _ = app.buttons["発見！ 花をながめて休む"].waitForExistence(timeout: 90)
        pause(6)

        // 4. Paint a little path towards the pond.
        app.buttons["tab-path"].tap()
        app.buttons["palette-path"].tap()
        pause(1)
        for y in [6, 5, 4] {
            tile(app, x: 9, y: y).tap()
            pause(0.6)
        }
        app.buttons["finish-path"].tap()
        pause(2)

        // 5. Move the house by dragging its ghost.
        tile(app, x: 3, y: 11).tap()
        pause(1)
        app.buttons["move-selection"].tap()
        pause(1)
        tile(app, x: 4, y: 12).press(forDuration: 0.3, thenDragTo: tile(app, x: 5, y: 13))
        pause(1.5)
        app.buttons["confirm-edit"].tap()
        pause(2)
        app.buttons["deselect"].tap()

        // 6. Add lamps, then switch to evening and night to see them light up.
        app.buttons["tab-decor"].tap()
        for spot in [(7, 9), (9, 7)] {
            app.buttons["palette-lamp"].tap()
            pause(0.8)
            tile(app, x: spot.0, y: spot.1).tap()
            pause(0.8)
            app.buttons["confirm-edit"].tap()
            pause(1)
            app.buttons["deselect"].tap()
        }
        app.buttons["day-phase"].tap()  // -> next phase
        pause(3)
        app.buttons["day-phase"].tap()
        pause(3)
        app.buttons["day-phase"].tap()
        pause(4)

        // 7. Invalid spot: a pond on the water shows the reason and cannot be confirmed.
        app.buttons["tab-nature"].tap()
        app.buttons["palette-pond"].tap()
        pause(1)
        tile(app, x: 0, y: 0).tap()
        pause(3)
        app.buttons["cancel-edit"].tap()
        pause(1)

        // 8. Field guide with snapshots, then a last look.
        app.buttons["field-guide"].tap()
        pause(4)
        app.buttons["閉じる"].tap()
        pause(6)
    }

    /// Screen point of a tile's center. Mirrors IslandScene.resetCamera + IsoGrid (64x32 tiles, 48pt base,
    /// camera margin 24, initial zoom 0.72), centered on the map.
    @MainActor
    private func tile(_ app: XCUIApplication, x: Int, y: Int) -> XCUICoordinate {
        let frame = app.windows.firstMatch.frame
        let map = CGSize(width: 1024, height: 560)
        let fitting = min(max((map.width + 48) / frame.width, (map.height + 48) / frame.height), 3.2)
        let scale = min(max(fitting * 0.72, 0.6), 3.2)
        let sceneX = (CGFloat(x) + 0.5 - (CGFloat(y) + 0.5) + 16) * 32
        let sceneY = (CGFloat(x) + 0.5 + CGFloat(y) + 0.5) * 16 + 48
        let point = CGVector(
            dx: frame.width / 2 + (sceneX - map.width / 2) / scale,
            dy: frame.height / 2 - (sceneY - map.height / 2) / scale)
        return app.coordinate(withNormalizedOffset: .zero).withOffset(point)
    }

    private func pause(_ seconds: TimeInterval) {
        Thread.sleep(forTimeInterval: seconds)
    }
}
