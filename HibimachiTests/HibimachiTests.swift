import Foundation
import HibimachiCore
import SpriteKit
import Testing

@testable import Hibimachi

/// In-memory repository so scene tests never touch the real save file.
final class MemoryRepository: WorldRepository, @unchecked Sendable {
    var stored: GameSnapshot?

    func load() -> WorldLoadOutcome { stored.map(WorldLoadOutcome.loaded) ?? .notFound }
    func save(_ snapshot: GameSnapshot) throws { stored = snapshot }
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

    @Test func pathPaintingAndNightLightsDoNotLeakNodes() {
        let (store, scene) = makeScene()
        scene.dayPhaseOverride = .day
        scene.syncWithStore(animated: false)
        let before = nodes(named: "*", in: scene)
        store.beginPaintingPath()
        for x in 2...6 { store.togglePath(at: TileCoord(x: x, y: 3)) }
        scene.syncWithStore(animated: false)
        scene.dayPhaseOverride = .night
        // One glow per lit building (the starting island has one house and no lamps).
        #expect(scene.glowLayer.children.count == 1)
        scene.dayPhaseOverride = .day
        #expect(scene.glowLayer.children.isEmpty)
        #expect(nodes(named: "*", in: scene) >= before - 1)
        #expect(nodes(named: "*", in: scene) <= before + 1)
    }

    @Test func manyTicksDoNotGrowTheNodeTree() {
        let (store, scene) = makeScene()
        scene.syncWithStore(animated: false)
        let before = nodes(named: "*", in: scene)
        for _ in 0..<200 {
            store.tick()
            scene.syncWithStore(animated: false)
        }
        // Newcomers may move in during the run (3 nodes each: the resident, its body and its emote).
        let newcomers = store.world.residents.count - 1
        #expect(nodes(named: "*", in: scene) == before + newcomers * 3)
    }

    @Test func everyResidentGetsOneNode() {
        let (store, scene) = makeScene()
        scene.syncWithStore(animated: false)
        #expect(nodes(named: "creature-*", in: scene) == 1)
        for _ in 0..<2_000 where store.world.residents.count < 2 { store.tick() }
        scene.syncWithStore(animated: false)
        #expect(nodes(named: "creature-*", in: scene) == store.world.residents.count)
    }
}

@MainActor
@Suite("Creature rendering")
struct CreatureNodeTests {
    @Test func everyKindAndSpeciesHasArt() {
        for kind in ObjectKind.allCases {
            for lit in [false, true] {
                let sprite = IslandArt.sprite(for: kind, lit: lit)
                #expect(sprite.image.width > 0 && sprite.anchor.x > 0 && sprite.anchor.x < 1)
            }
        }
        for species in Species.allCases {
            #expect(IslandArt.creatureImage(species).width == 22)
        }
    }

    @Test func moveActionIsStartedOncePerNewTile() throws {
        let world = IslandFactory.makeWorld()
        let grid = IsoGrid(columns: world.width, rows: world.height)
        let node = CreatureNode(species: .mochi)
        node.show(world.creature, in: world, grid: grid, animated: false, reduceMotion: true)
        #expect(node.action(forKey: "move") == nil)

        var moved = world
        moved.creature.position = moved.creature.position.offset(dx: 1, dy: 0)
        node.show(moved.creature, in: moved, grid: grid, animated: true, reduceMotion: true)
        let firstAction = try #require(node.action(forKey: "move"))
        // Rendering the same state again (next frame) must not restart the running move.
        node.show(moved.creature, in: moved, grid: grid, animated: true, reduceMotion: true)
        #expect(node.action(forKey: "move") === firstAction)
    }
}

@Suite("Player-facing text")
struct GameTextTests {
    @Test func everyKindAndReactionHasCopy() {
        for kind in ObjectKind.allCases {
            #expect(!kind.displayName.isEmpty)
            #expect(PaletteTab.allCases.contains { $0.kinds.contains(kind) }, "\(kind) must be buildable")
        }
        for species in Species.allCases {
            #expect(!species.displayName.isEmpty && !species.arrivalLine.isEmpty)
        }
        for reaction in ReactionKind.allCases {
            #expect(!reaction.title.isEmpty && !reaction.detail.isEmpty && !reaction.emote.isEmpty)
        }
        for terrain in Terrain.allCases {
            #expect(!PlacementError.blockedByTerrain(terrain).message.isEmpty)
        }
    }
}
