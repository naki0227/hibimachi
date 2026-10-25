import Foundation
import HibimachiCore
import SpriteKit
import Testing

@testable import Hibimachi

/// In-memory repository so scene tests never touch the real save file.
final class MemoryRepository: WorldRepository, @unchecked Sendable {
    var stored: World?

    func load() -> WorldLoadOutcome { stored.map(WorldLoadOutcome.loaded) ?? .notFound }
    func save(_ world: World) throws { stored = world }
}

@MainActor
@Suite("Island scene rendering")
struct IslandSceneTests {
    private func makeScene() -> (GameStore, IslandScene) {
        let store = GameStore(repository: MemoryRepository(), seed: 1)
        return (store, IslandScene(store: store))
    }

    private func nodes(named name: String, in scene: SKScene) -> Int {
        var count = 0
        scene.enumerateChildNodes(withName: "//\(name)") { _, _ in count += 1 }
        return count
    }

    @Test func rendersOneNodePerObject() {
        let (store, scene) = makeScene()
        #expect(scene.objectNodes.count == store.world.objects.count)
        #expect(Set(scene.objectNodes.keys) == Set(store.world.objects.map(\.id)))
    }

    @Test func placingAndUndoKeepNodesInSync() {
        let (store, scene) = makeScene()
        store.beginPlacing(.flower)
        scene.syncWithStore(animated: false)
        #expect(nodes(named: "preview", in: scene) == 1)

        #expect(store.confirmPreview())
        scene.syncWithStore(animated: false)
        #expect(scene.objectNodes.count == 7)
        #expect(nodes(named: "preview", in: scene) == 0)
        #expect(nodes(named: "selection", in: scene) == 1)

        store.undo()
        scene.syncWithStore(animated: false)
        #expect(scene.objectNodes.count == 6)
        #expect(nodes(named: "selection", in: scene) == 0)
    }

    @Test func resettingLeavesNoGhostNodes() {
        let (store, scene) = makeScene()
        let oldIDs = Set(store.world.objects.map(\.id))
        store.resetIsland()
        scene.syncWithStore(animated: false)
        #expect(scene.objectNodes.count == 6)
        #expect(Set(scene.objectNodes.keys).isDisjoint(with: oldIDs))
        #expect(nodes(named: "object-*", in: scene) == 6)
    }

    @Test func manyTicksDoNotGrowTheNodeTree() {
        let (store, scene) = makeScene()
        scene.syncWithStore(animated: false)
        let before = nodes(named: "*", in: scene)
        for _ in 0..<200 {
            store.tick()
            scene.syncWithStore(animated: false)
        }
        #expect(nodes(named: "*", in: scene) == before)
    }
}

@MainActor
@Suite("Creature rendering")
struct CreatureNodeTests {
    @Test func moveActionIsStartedOncePerNewTile() throws {
        let world = IslandFactory.makeWorld()
        let geometry = GridGeometry(tileSize: 32, columns: world.width, rows: world.height)
        let node = CreatureNode()
        node.show(world.creature, in: world, geometry: geometry, animated: false, reduceMotion: true)
        #expect(node.action(forKey: "move") == nil)

        var moved = world
        moved.creature.position = moved.creature.position.offset(dx: 1, dy: 0)
        node.show(moved.creature, in: moved, geometry: geometry, animated: true, reduceMotion: true)
        let firstAction = try #require(node.action(forKey: "move"))
        // Rendering the same state again (next frame) must not restart the running move.
        node.show(moved.creature, in: moved, geometry: geometry, animated: true, reduceMotion: true)
        #expect(node.action(forKey: "move") === firstAction)
    }
}

@Suite("Player-facing text")
struct GameTextTests {
    @Test func everyKindAndReactionHasCopy() {
        for kind in ObjectKind.allCases {
            #expect(!kind.displayName.isEmpty && !kind.symbolName.isEmpty)
        }
        for reaction in ReactionKind.allCases {
            #expect(!reaction.title.isEmpty && !reaction.detail.isEmpty && !reaction.emote.isEmpty)
        }
        for terrain in Terrain.allCases {
            #expect(!PlacementError.blockedByTerrain(terrain).message.isEmpty)
        }
    }
}
