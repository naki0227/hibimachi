import Testing

@testable import HibimachiCore

@Suite("Starting island")
struct IslandFactoryTests {
    @Test func defaultIslandMatchesTheVerticalSliceSpec() {
        let ids = SequentialIDs()
        let world = IslandFactory.makeWorld(makeID: ids.make)
        #expect(world.width == IslandGrowth.mapSize && world.height == IslandGrowth.mapSize)
        #expect(world.growthStage == 0)
        // The 16x16 layout sits in the middle with two rings of sea to grow into.
        #expect(world.terrain(at: TileCoord(x: 1, y: 1)) == .water)
        #expect(world.terrain(at: TileCoord(x: 10, y: 10)) == Terrain(rawValue: Array(IslandFactory.layout[7])[8]))
        #expect(Set(world.terrain) == Set(Terrain.allCases))
        // Vertical slice spec: two trees, a house, a bench, a flower and a pond. Lamps are built by the player.
        #expect(Set(world.objects.map(\.kind)) == [.roundTree, .pineTree, .house, .bench, .flower, .pond])
        #expect(world.isWalkable(world.creature.position))
        #expect(world.discoveries.isEmpty)
    }

    @Test func layoutRowsAreSquare() {
        #expect(IslandFactory.layout.allSatisfy { $0.count == IslandFactory.size })
        #expect(IslandFactory.makeTerrain().count == IslandFactory.size * IslandFactory.size)
    }

    @Test func bottomRowOfLayoutIsYZero() {
        let terrain = IslandFactory.makeTerrain()
        // Bottom-left of the layout ("w") and the tile above the bottom-left path cell.
        #expect(terrain[0] == .water)
        let row1 = Array(IslandFactory.layout[IslandFactory.size - 2])
        #expect(terrain[IslandFactory.size + 8] == Terrain(rawValue: row1[8]))
    }

    @Test func creatureReactsWithinAMinuteOnTheDefaultIsland() {
        var world = IslandFactory.makeWorld()
        // ~0.45 s per tick: 130 ticks ≈ 1 minute. First-session players should see something happen.
        let events = simulate(&world, seed: 2026, limit: 130) { if case .discovered = $0 { true } else { false } }
        #expect(events.contains { if case .discovered = $0 { true } else { false } })
    }
}
