import Foundation
import Testing

@testable import HibimachiCore

/// In-memory repository that records saves and can be told to fail.
final class FakeRepository: WorldRepository, @unchecked Sendable {
    struct SaveFailed: Error {}

    var loadOutcome: WorldLoadOutcome
    var failSaves = false
    private(set) var saved: [World] = []

    init(_ outcome: WorldLoadOutcome = .notFound) {
        loadOutcome = outcome
    }

    func load() -> WorldLoadOutcome { loadOutcome }

    func save(_ world: World) throws {
        if failSaves { throw SaveFailed() }
        saved.append(world)
    }
}

@MainActor
@Suite("GameStore use cases")
struct GameStoreTests {
    @Test func firstLaunchCreatesAndSavesTheDefaultIsland() {
        let repository = FakeRepository()
        let store = GameStore(repository: repository, seed: 1)
        #expect(store.world.objects.count == 6)
        #expect(repository.saved.count == 1)
        #expect(store.startupNotice == nil)
    }

    @Test func unreadableSaveStartsFreshAndTellsThePlayer() {
        let repository = FakeRepository(.unreadable(reason: "broken", backupFileName: "world.unreadable-x.json"))
        let store = GameStore(repository: repository, seed: 1)
        #expect(store.startupNotice == .recoveredFromUnreadableSave(backupFileName: "world.unreadable-x.json"))
        #expect(repository.saved.count == 1)
        store.dismissStartupNotice()
        #expect(store.startupNotice == nil)
    }

    @Test func loadsAnExistingIslandWithoutResaving() throws {
        let world = try TestWorlds.grass(objects: [TestWorlds.object(.flower, 1, 1)])
        let repository = FakeRepository(.loaded(world))
        let store = GameStore(repository: repository, seed: 1)
        #expect(store.world == world)
        #expect(repository.saved.isEmpty)
    }

    @Test func placeFlowPreviewsConfirmsSavesAndUndoes() throws {
        let repository = FakeRepository(.loaded(try TestWorlds.grass(creatureAt: TileCoord(x: 3, y: 3))))
        let store = GameStore(repository: repository, seed: 1)
        store.beginPlacing(.house)
        #expect(store.previewKind == .house)
        #expect(store.previewIssue == nil)  // Suggested spot is always valid when one exists.

        store.setPreviewOrigin(TileCoord(x: 50, y: -3))  // Clamped inside the map.
        #expect(store.previewOrigin == TileCoord(x: 6, y: 0))
        store.nudgePreview(dx: -1, dy: 1)
        #expect(store.previewOrigin == TileCoord(x: 5, y: 1))

        #expect(store.confirmPreview())
        #expect(store.mode == .browse)
        #expect(store.world.objects.map(\.origin) == [TileCoord(x: 5, y: 1)])
        #expect(store.selectedObject?.kind == .house)
        #expect(store.objectsRevision == 1)
        #expect(repository.saved.last?.objects.count == 1)

        store.undo()
        #expect(store.world.objects.isEmpty)
        #expect(store.selectedObjectID == nil)
        #expect(repository.saved.last?.objects.isEmpty == true)
    }

    @Test func invalidConfirmExplainsWhyAndChangesNothing() throws {
        let tree = TestWorlds.object(.roundTree, 2, 2)
        let repository = FakeRepository(.loaded(try TestWorlds.grass(objects: [tree])))
        let store = GameStore(repository: repository, seed: 1)
        store.beginPlacing(.flower)
        store.setPreviewOrigin(tree.origin)
        #expect(store.previewIssue == .overlapsObject(tree.id))
        #expect(!store.confirmPreview())
        #expect(store.lastRejection == .overlapsObject(tree.id))
        #expect(store.world.objects == [tree])
        #expect(repository.saved.isEmpty)
        store.nudgePreview(dx: 1, dy: 0)
        #expect(store.lastRejection == nil)
    }

    @Test func selectMoveAndRemove() throws {
        let bench = TestWorlds.object(.bench, 1, 1)
        let store = GameStore(repository: FakeRepository(.loaded(try TestWorlds.grass(objects: [bench]))), seed: 1)
        store.selectObject(at: TileCoord(x: 5, y: 5))
        #expect(store.selectedObjectID == nil)
        store.selectObject(at: bench.origin)
        #expect(store.selectedObjectID == bench.id)

        store.beginMovingSelection()
        #expect(store.mode == .moving(bench.id, origin: bench.origin))
        #expect(store.previewIssue == nil)  // Staying in place is a valid move.
        store.setPreviewOrigin(TileCoord(x: 4, y: 4))
        #expect(store.previewIssue == nil)
        #expect(store.confirmPreview())
        #expect(store.world.object(withID: bench.id)?.origin == TileCoord(x: 4, y: 4))

        store.removeSelection()
        #expect(store.world.objects.isEmpty)
        store.undo()
        #expect(store.world.object(withID: bench.id)?.origin == TileCoord(x: 4, y: 4))
    }

    @Test func movePreviewReportsOverlapAndMissingObject() throws {
        let bench = TestWorlds.object(.bench, 1, 1)
        let tree = TestWorlds.object(.roundTree, 3, 3)
        let store = GameStore(
            repository: FakeRepository(.loaded(try TestWorlds.grass(objects: [bench, tree]))), seed: 1)
        store.select(bench.id)
        store.beginMovingSelection()
        store.setPreviewOrigin(tree.origin)
        #expect(store.previewIssue == .overlapsObject(tree.id))
        #expect(!store.confirmPreview())
        #expect(store.world.object(withID: bench.id)?.origin == bench.origin)
    }

    @Test func cancelLeavesTheIslandUntouched() throws {
        let store = GameStore(repository: FakeRepository(.loaded(try TestWorlds.grass())), seed: 1)
        store.beginPlacing(.pond)
        store.cancelEdit()
        #expect(store.mode == .browse)
        #expect(store.world.objects.isEmpty)
        #expect(!store.confirmPreview())
    }

    @Test func saveFailureKeepsTheIslandAndRecoversOnRetry() throws {
        let repository = FakeRepository(.loaded(try TestWorlds.grass()))
        let store = GameStore(repository: repository, seed: 1)
        repository.failSaves = true
        store.beginPlacing(.flower)
        #expect(store.confirmPreview())
        #expect(store.world.objects.count == 1)
        #expect(store.saveErrorMessage != nil)

        repository.failSaves = false
        store.persist()
        #expect(store.saveErrorMessage == nil)
        #expect(repository.saved.last?.objects.count == 1)
    }

    @Test func discoveriesAreQueuedAndSavedOnce() throws {
        let bench = TestWorlds.object(.bench, 4, 3)
        let repository = FakeRepository(
            .loaded(try TestWorlds.grass(objects: [bench], creatureAt: TileCoord(x: 3, y: 3))))
        let store = GameStore(repository: repository, seed: 5)
        var discovered: [WorldEvent] = []
        for _ in 0..<600 {
            discovered += store.tick().filter { if case .discovered = $0 { true } else { false } }
        }
        #expect(discovered == [.discovered(.benchRest)])
        #expect(store.pendingDiscoveries == [.benchRest])
        #expect(repository.saved.count == 1)
        #expect(repository.saved.last?.discoveries == [.benchRest])
        store.dismissDiscovery()
        store.dismissDiscovery()
        #expect(store.pendingDiscoveries.isEmpty)
    }

    @Test func resetRestoresTheDefaultIsland() throws {
        let store = GameStore(repository: FakeRepository(.loaded(try TestWorlds.grass())), seed: 1)
        store.resetIsland()
        #expect(store.world.objects.count == 6)
        #expect(!store.canUndo)
    }

    @Test func editingIsIgnoredWhileNotInTheRightMode() throws {
        let bench = TestWorlds.object(.bench, 1, 1)
        let store = GameStore(repository: FakeRepository(.loaded(try TestWorlds.grass(objects: [bench]))), seed: 1)
        store.beginMovingSelection()  // nothing selected
        #expect(store.mode == .browse)
        store.beginPlacing(.flower)
        store.selectObject(at: bench.origin)  // taps move the preview instead of selecting
        #expect(store.selectedObjectID == nil)
        store.removeSelection()
        #expect(store.world.objects.count == 1)
    }
}
