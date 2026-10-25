import Foundation
import Testing

@testable import HibimachiCore

@Suite("Placement rules")
struct PlacementTests {
    @Test func placesOnFreeGrass() throws {
        var world = try TestWorlds.grass()
        let result = world.place(.house, at: TileCoord(x: 2, y: 2), id: UUID())
        let placed = try result.get()
        #expect(world.objects == [placed])
        #expect(world.object(at: TileCoord(x: 3, y: 3))?.id == placed.id)
        #expect(world.object(at: TileCoord(x: 4, y: 4)) == nil)
    }

    @Test(arguments: [
        TileCoord(x: -1, y: 0), TileCoord(x: 0, y: -1), TileCoord(x: 7, y: 0), TileCoord(x: 0, y: 7),
        TileCoord(x: 8, y: 8), TileCoord(x: 100, y: 3),
    ])
    func rejectsTwoByTwoOutsideMap(origin: TileCoord) throws {
        var world = try TestWorlds.grass()
        let result1 = world.place(.pond, at: origin, id: UUID())
        #expect(result1 == .failure(.outOfBounds))
        #expect(world.objects.isEmpty)
    }

    @Test func acceptsFootprintTouchingTheLastRowAndColumn() throws {
        var world = try TestWorlds.grass()
        #expect(throws: Never.self) { try world.place(.pond, at: TileCoord(x: 6, y: 6), id: UUID()).get() }
    }

    @Test func rejectsWaterForEveryKind() throws {
        let world = try TestWorlds.grass(waterColumn: 3)
        for kind in ObjectKind.allCases {
            #expect(world.placementIssue(for: kind, at: TileCoord(x: 3, y: 1)) == .blockedByTerrain(.water))
        }
    }

    @Test func benchMayStandOnPathButHouseMayNot() throws {
        let world = try TestWorlds.grass(pathRow: 2)
        #expect(world.placementIssue(for: .bench, at: TileCoord(x: 1, y: 2)) == nil)
        #expect(world.placementIssue(for: .house, at: TileCoord(x: 1, y: 1)) == .blockedByTerrain(.path))
    }

    @Test func rejectsOverlapAndNamesTheBlocker() throws {
        let tree = TestWorlds.object(.roundTree, 3, 3)
        var world = try TestWorlds.grass(objects: [tree])
        let result2 = world.place(.house, at: TileCoord(x: 2, y: 2), id: UUID())
        #expect(result2 == .failure(.overlapsObject(tree.id)))
        #expect(world.objects == [tree])
    }

    @Test func moveMayOverlapItsOwnPreviousTiles() throws {
        let pond = TestWorlds.object(.pond, 2, 2)
        var world = try TestWorlds.grass(objects: [pond])
        let moved = try world.moveObject(pond.id, to: TileCoord(x: 3, y: 2)).get()
        #expect(moved.origin == TileCoord(x: 3, y: 2))
    }

    @Test func moveAndRemoveOfUnknownObjectFail() throws {
        var world = try TestWorlds.grass()
        let id = UUID()
        let result3 = world.moveObject(id, to: TileCoord(x: 1, y: 1))
        #expect(result3 == .failure(.unknownObject(id)))
        let result4 = world.removeObject(id)
        #expect(result4 == .failure(.unknownObject(id)))
    }

    @Test func placingOnTheCreatureMakesItHopAside() throws {
        var world = try TestWorlds.grass(creatureAt: TileCoord(x: 4, y: 4))
        _ = try world.place(.house, at: TileCoord(x: 4, y: 4), id: UUID()).get()
        #expect(world.isWalkable(world.creature.position))
        #expect(world.creature.position.chebyshevDistance(to: TileCoord(x: 4, y: 4)) <= 2)
    }

    @Test func emptyIslandIsValid() throws {
        let world = try TestWorlds.grass()
        #expect(world.objects.isEmpty)
        #expect(world.discoveries.isEmpty)
    }

    @Test func worldInitRejectsInconsistentData() {
        let creature = Creature(id: UUID(), position: TileCoord(x: 0, y: 0))
        #expect(throws: WorldValidationError.invalidSize) {
            try World(width: 0, height: 4, terrain: [], objects: [], creature: creature)
        }
        #expect(throws: WorldValidationError.terrainCountMismatch(expected: 4, actual: 3)) {
            try World(width: 2, height: 2, terrain: [.grass, .grass, .grass], objects: [], creature: creature)
        }
        let id = UUID()
        let duplicate = [TestWorlds.object(.flower, 0, 1, id: id), TestWorlds.object(.flower, 1, 1, id: id)]
        #expect(throws: WorldValidationError.duplicateObjectID(id)) {
            try TestWorlds.grass(objects: duplicate)
        }
        let a = TestWorlds.object(.house, 1, 1)
        let b = TestWorlds.object(.flower, 2, 2)
        #expect(throws: WorldValidationError.invalidObject(b.id, .overlapsObject(a.id))) {
            try TestWorlds.grass(objects: [a, b])
        }
        #expect(throws: WorldValidationError.creatureOutOfBounds) {
            try TestWorlds.grass(creatureAt: TileCoord(x: 9, y: 0))
        }
    }

    @Test func discoveriesAreRecordedOnlyOnce() throws {
        var world = try TestWorlds.grass()
        let result5 = world.recordDiscovery(.treeNap)
        #expect(result5)
        let result6 = world.recordDiscovery(.treeNap)
        #expect(!result6)
        #expect(world.discoveries == [.treeNap])
    }
}
