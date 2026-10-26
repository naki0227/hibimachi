import Foundation
import Testing

@testable import HibimachiCore

@Suite("Path painting")
struct PathPaintingTests {
    @Test func togglesGrassAndPathAndUndoes() throws {
        var editor = WorldEditor(world: try TestWorlds.grass())
        let tile = TileCoord(x: 2, y: 2)
        let first = editor.togglePath(at: tile)
        #expect(first == .success(.path))
        #expect(editor.world.terrain(at: tile) == .path)
        let second = editor.togglePath(at: tile)
        #expect(second == .success(.grass))
        let undidSecond = editor.undo()
        #expect(undidSecond)
        #expect(editor.world.terrain(at: tile) == .path)
        let undidFirst = editor.undo()
        #expect(undidFirst)
        #expect(editor.world.terrain(at: tile) == .grass)
    }

    @Test func waterAndOutsideCannotBePainted() throws {
        var world = try TestWorlds.grass(waterColumn: 3)
        let water = world.togglePath(at: TileCoord(x: 3, y: 1))
        let outside = world.togglePath(at: TileCoord(x: -1, y: 1))
        #expect(water == .failure(.blockedByTerrain(.water)))
        #expect(outside == .failure(.outOfBounds))
    }

    @Test func objectsKeepTheirAllowedGround() throws {
        let house = TestWorlds.object(.house, 1, 1)
        let bench = TestWorlds.object(.bench, 5, 5)
        var world = try TestWorlds.grass(objects: [house, bench])
        // A house cannot end up standing on a path...
        let underHouse = world.togglePath(at: TileCoord(x: 2, y: 2))
        #expect(underHouse == .failure(.overlapsObject(house.id)))
        // ...but a bench may.
        let underBench = world.togglePath(at: TileCoord(x: 5, y: 5))
        #expect(underBench == .success(.path))
    }

    @MainActor
    @Test func storeStaysInPaintModeAcrossUndo() throws {
        let store = GameStore(repository: FakeRepository(.loaded(try TestWorlds.grass())), seed: 1)
        store.beginPaintingPath()
        #expect(store.togglePath(at: TileCoord(x: 1, y: 1)))
        #expect(store.terrainRevision == 1)
        store.undo()
        #expect(store.mode == .paintingPath)
        #expect(store.world.terrain(at: TileCoord(x: 1, y: 1)) == .grass)
        store.cancelEdit()
        #expect(!store.togglePath(at: TileCoord(x: 1, y: 1)))
    }

    @MainActor
    @Test func rejectedPaintExplainsWhy() throws {
        let store = GameStore(repository: FakeRepository(.loaded(try TestWorlds.grass(waterColumn: 0))), seed: 1)
        store.beginPaintingPath()
        #expect(!store.togglePath(at: TileCoord(x: 0, y: 0)))
        #expect(store.lastRejection == .blockedByTerrain(.water))
    }
}
