import Foundation
import Testing

@testable import HibimachiCore

@Suite("Island growth")
struct IslandGrowthTests {
    private func landCount(_ world: World) -> Int { world.terrain.filter(\.isLand).count }

    private func game(_ world: World, xp: Int) throws -> GameSnapshot {
        let earned = RewardTransaction(
            id: UUID(), reason: .welcome, xpDelta: xp, sparkleDelta: 1_000, ruleVersion: 1,
            date: Date(timeIntervalSince1970: 0))
        return GameSnapshot(world: world, progress: try PlayerProgress(ledger: [earned]))
    }

    @Test func stagesAreEarnedByLevelOrByDiscoveries() {
        #expect(IslandGrowth.earnedStages(level: 1, discoveries: 0) == 0)
        #expect(IslandGrowth.earnedStages(level: 3, discoveries: 0) == 1)
        #expect(IslandGrowth.earnedStages(level: 1, discoveries: 6) == 1, "playing the island alone grows it too")
        #expect(IslandGrowth.earnedStages(level: 5, discoveries: 0) == 2)
        #expect(IslandGrowth.earnedStages(level: 9, discoveries: 99) == IslandGrowth.stages.count)
        #expect(IslandGrowth.nextStage(after: 0)?.level == 3)
        #expect(IslandGrowth.nextStage(after: IslandGrowth.stages.count) == nil)
    }

    @Test func eachGrowthAddsARingOfLandButKeepsSeaAtTheEdge() {
        var world = IslandFactory.makeWorld()
        #expect(world.landSpan == IslandFactory.size - 2, "the starting layout has one ring of sea inside it")
        let start = landCount(world)
        let objects = world.objects
        for stage in 1...IslandGrowth.stages.count {
            let ring = world.grow()
            #expect(!ring.isEmpty)
            #expect(world.growthStage == stage)
            #expect(ring.allSatisfy { world.terrain(at: $0) == .grass })
        }
        #expect(landCount(world) > start + 40, "two rings make the island noticeably larger")
        let size = IslandGrowth.mapSize
        let edge = (0..<size).flatMap {
            [
                TileCoord(x: $0, y: 0), TileCoord(x: $0, y: size - 1),
                TileCoord(x: 0, y: $0), TileCoord(x: size - 1, y: $0),
            ]
        }
        #expect(edge.allSatisfy { world.terrain(at: $0) == .water })
        #expect(world.objects == objects, "growth never moves what the player placed")
        #expect(world.landSpan == IslandFactory.size + 2 * IslandGrowth.stages.count - 2)
    }

    @MainActor
    @Test func reachingALevelGrowsTheIslandOnceAndAnnouncesIt() throws {
        let repository = FakeRepository(.loaded(try game(IslandFactory.makeWorld(), xp: 2 * RewardRule.xpPerLevel)))
        let store = GameStore(repository: repository, seed: 1)
        #expect(store.world.growthStage == 1)
        #expect(store.pendingGrowths == 1)
        #expect(store.terrainRevision == 1)
        #expect(repository.saved.last?.world.growthStage == 1, "saved at launch")
        #expect(store.nextGrowth?.level == 5)
        store.dismissGrowth()
        #expect(store.pendingGrowths == 0)

        // Reloading the same save does not grow it again.
        let again = GameStore(repository: FakeRepository(.loaded(try #require(repository.saved.last))), seed: 1)
        #expect(again.world.growthStage == 1 && again.pendingGrowths == 0)
    }

    @MainActor
    @Test func growthClearsUndoSoTheNewLandCannotBeTakenBack() throws {
        let repository = FakeRepository(.loaded(try game(IslandFactory.makeWorld(), xp: 0)))
        let store = GameStore(repository: repository, seed: 1)
        #expect(store.beginPlacing(.flower))
        #expect(store.confirmPreview())
        #expect(store.canUndo)
        for kind in ReactionKind.allCases.prefix(6) { store.editor.world.recordDiscovery(kind) }
        store.tick()  // a discovery-free tick does not check growth
        #expect(store.world.growthStage == 0)
        store.growIslandIfDue()
        #expect(store.world.growthStage == 1)
        #expect(!store.canUndo)
    }

    @MainActor
    @Test func startingOverKeepsTheSizeTheIslandHadEarned() throws {
        let store = GameStore(
            repository: FakeRepository(.loaded(try game(IslandFactory.makeWorld(), xp: 4 * RewardRule.xpPerLevel))),
            seed: 1)
        #expect(store.world.growthStage == 2)
        store.dismissGrowth()
        store.dismissGrowth()
        store.resetIsland()
        #expect(store.world.growthStage == 2)
        #expect(store.pendingGrowths == 0, "nothing new to announce")
    }
}
