import HibimachiCore
import HibimachiStorage
import SwiftUI

@main
struct HibimachiApp: App {
    @State private var store = AppComposition.makeStore()
    @State private var tutorial = AppComposition.makeTutorial()
    @State private var settings = AppSettings()
    @Environment(\.scenePhase) private var scenePhase

    var body: some Scene {
        WindowGroup {
            IslandScreen(
                store: store, tutorial: tutorial, settings: settings, initialPhase: AppComposition.dayPhaseOverride()
            )
            // The art and UI kit are one light paper palette; Dark Mode would only flip system colors
            // (text, keyboard, pickers) and make them unreadable on it.
            .preferredColorScheme(.light)
        }
        .onChange(of: scenePhase) { _, phase in
            switch phase {
            case .active:
                // The widget may have completed quests while the app was away.
                store.reloadProgressFromStorage()
                SoundPlayer.shared.setActive(true)
            case .background:
                // Edits are saved immediately; this also captures the creature's position before suspension.
                // Only on .background: saving on the way back (.inactive) would overwrite the widget's changes.
                store.persist()
                WidgetSync.reloadWidgets()
                SoundPlayer.shared.setActive(false)
            default:
                break
            }
        }
    }
}

/// Composition root: the only place that knows which repository / seed the game uses.
@MainActor
enum AppComposition {
    static func makeStore(environment: [String: String] = ProcessInfo.processInfo.environment) -> GameStore {
        // UI tests pass a unique folder name and a fixed seed so each run is isolated and reproducible.
        let folder = environment["HIBIMACHI_STORAGE_NAME"] ?? SharedContainer.saveFolder
        let seed = environment["HIBIMACHI_SEED"].flatMap(UInt64.init) ?? UInt64.random(in: .min ... .max)
        let appSupport =
            FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? FileManager.default.temporaryDirectory
        // The save lives in the App Group so the widget can read it; without the group, in the app's own folder.
        let appFolder = appSupport.appendingPathComponent(folder, isDirectory: true)
        let directory =
            SharedContainer.groupURL.map { saveDirectory(in: $0, folder: folder, legacy: appFolder) } ?? appFolder
        // Photos stay in the app's own folder: the widget never needs them, so they are not shared with it.
        let media = FileMediaStore(directory: appFolder.appendingPathComponent("media", isDirectory: true))
        return GameStore(repository: JSONFileWorldRepository(directory: directory), seed: seed, media: media)
    }

    /// Saves made before the widget live in Application Support; they move into the group once, never over a
    /// newer save. If the move fails the game keeps using the old folder, so nothing looks lost.
    private static func saveDirectory(in group: URL, folder: String, legacy: URL) -> URL {
        let fileManager = FileManager.default
        let shared = group.appendingPathComponent(folder, isDirectory: true)
        let oldFile = legacy.appendingPathComponent(JSONFileWorldRepository.fileName)
        let newFile = shared.appendingPathComponent(JSONFileWorldRepository.fileName)
        guard fileManager.fileExists(atPath: oldFile.path), !fileManager.fileExists(atPath: newFile.path) else {
            return shared
        }
        do {
            try fileManager.createDirectory(at: shared, withIntermediateDirectories: true)
            try fileManager.moveItem(at: oldFile, to: newFile)
            return shared
        } catch {
            return legacy
        }
    }

    /// UI tests that are not about the tutorial turn it off with HIBIMACHI_TUTORIAL=off.
    static func makeTutorial(environment: [String: String] = ProcessInfo.processInfo.environment) -> TutorialCoach {
        TutorialCoach(
            storageName: environment["HIBIMACHI_STORAGE_NAME"] ?? SharedContainer.saveFolder,
            enabled: environment["HIBIMACHI_TUTORIAL"] != "off")
    }

    /// Demos and UI tests pin the time of day (CI simulators run on UTC, which is often "night").
    static func dayPhaseOverride(environment: [String: String] = ProcessInfo.processInfo.environment) -> DayPhase? {
        environment["HIBIMACHI_DAY_PHASE"].flatMap(DayPhase.init(rawValue:))
    }
}
