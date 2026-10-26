import XCTest

/// Runs the app in English and checks that the main screens show no Japanese. Catches strings that bypass the
/// catalog (plain `String` literals, ternaries) and keys whose catalog entry does not match the source.
final class EnglishUITests: XCTestCase {
    override func setUp() {
        continueAfterFailure = false
    }

    @MainActor
    func testMainScreensAreInEnglish() {
        let app = XCUIApplication()
        app.launchEnvironment["HIBIMACHI_STORAGE_NAME"] = "uitest-en-\(UUID().uuidString)"
        app.launchEnvironment["HIBIMACHI_TUTORIAL"] = "off"
        app.launchEnvironment["HIBIMACHI_SEED"] = "2026"
        app.launchEnvironment["HIBIMACHI_AUDIO"] = "off"
        app.launchEnvironment["HIBIMACHI_DAY_PHASE"] = "day"
        app.launchArguments += ["-AppleLanguages", "(en)", "-AppleLocale", "en_US"]
        app.launch()
        XCTAssertTrue(app.descendants(matching: .any)["island-view"].waitForExistence(timeout: 15))
        assertNoJapanese(app, "island")

        // Palette with locked items (their unlock hints) and the placing bar.
        app.buttons["tab-decor"].tap()
        assertNoJapanese(app, "palette")
        app.buttons["tab-nature"].tap()
        app.buttons["palette-flower"].tap()
        assertNoJapanese(app, "placing")
        app.buttons["confirm-edit"].tap()
        assertNoJapanese(app, "selection")

        // A goal created in English gets English preset quests.
        app.buttons["quests"].tap()
        app.buttons["goal-category-tidy"].tap()
        assertNoJapanese(app, "new-goal")
        app.buttons["create-goal"].tap()
        XCTAssertTrue(app.buttons["quest-done-0"].waitForExistence(timeout: 5))
        app.buttons["quest-done-0"].tap()
        assertNoJapanese(app, "quests")
        app.buttons["panel-close"].tap()

        for (identifier, name) in [("field-guide", "field-guide"), ("album", "album"), ("object-list", "objects")] {
            app.buttons[identifier].tap()
            assertNoJapanese(app, name)
            app.buttons["panel-close"].tap()
        }

        app.buttons["Menu"].tap()
        assertNoJapanese(app, "menu")
        app.buttons["Settings"].tap()
        XCTAssertTrue(app.descendants(matching: .any)["settings-panel"].waitForExistence(timeout: 5))
        XCTAssertEqual(app.descendants(matching: .any)["setting-music"].firstMatch.value as? String, "1")
        assertNoJapanese(app, "settings")
    }

    @MainActor
    private func assertNoJapanese(_ app: XCUIApplication, _ screen: String) {
        Thread.sleep(forTimeInterval: 0.5)
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = "en-\(screen)"
        attachment.lifetime = .keepAlways
        add(attachment)
        // One snapshot of the whole tree: querying elements one by one races with toasts and animations.
        guard let root = try? app.snapshot() else {
            XCTFail("No accessibility snapshot on the \(screen) screen")
            return
        }
        let japanese = labels(in: root).filter { label in
            label.unicodeScalars.contains {
                (0x3040...0x30FF).contains($0.value) || (0x4E00...0x9FFF).contains($0.value)
            }
        }
        XCTAssertEqual(japanese, [], "Japanese text on the \(screen) screen")
    }

    /// Labels and text values (e.g. a toggle's spoken state) of every element in the tree.
    @MainActor
    private func labels(in snapshot: XCUIElementSnapshot) -> [String] {
        [snapshot.label, snapshot.value as? String ?? ""] + snapshot.children.flatMap { labels(in: $0) }
    }
}
