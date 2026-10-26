import HibimachiCore
import HibimachiStorage
import SwiftUI

@main
struct HibimachiApp: App {
    @State private var store = AppComposition.makeStore()
    @Environment(\.scenePhase) private var scenePhase

    var body: some Scene {
        WindowGroup {
            IslandScreen(store: store, initialPhase: AppComposition.dayPhaseOverride())
        }
        .onChange(of: scenePhase) { _, phase in
            // Edits are saved immediately; this also captures the creature's position before suspension.
            if phase != .active { store.persist() }
        }
    }
}

/// Composition root: the only place that knows which repository / seed the game uses.
@MainActor
enum AppComposition {
    static func makeStore(environment: [String: String] = ProcessInfo.processInfo.environment) -> GameStore {
        // UI tests pass a unique folder name and a fixed seed so each run is isolated and reproducible.
        let folder = environment["HIBIMACHI_STORAGE_NAME"] ?? "Hibimachi"
        let seed = environment["HIBIMACHI_SEED"].flatMap(UInt64.init) ?? UInt64.random(in: .min ... .max)
        let base =
            FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? FileManager.default.temporaryDirectory
        let repository = JSONFileWorldRepository(directory: base.appendingPathComponent(folder, isDirectory: true))
        return GameStore(repository: repository, seed: seed)
    }

    /// Demos and UI tests pin the time of day (CI simulators run on UTC, which is often "night").
    static func dayPhaseOverride(environment: [String: String] = ProcessInfo.processInfo.environment) -> DayPhase? {
        environment["HIBIMACHI_DAY_PHASE"].flatMap(DayPhase.init(rawValue:))
    }
}
