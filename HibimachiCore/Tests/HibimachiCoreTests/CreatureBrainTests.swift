import Foundation
import Testing

@testable import HibimachiCore

@Suite("Creature reactions")
struct CreatureBrainTests {
    private func started(_ events: [WorldEvent]) -> [ReactionKind] {
        events.compactMap { event in
            if case .reactionStarted(let kind, _, _) = event { return kind }
            return nil
        }
    }

    @Test func sameSeedSameBehaviour() throws {
        let base = try TestWorlds.grass(
            objects: [TestWorlds.object(.bench, 5, 5), TestWorlds.object(.roundTree, 1, 6)],
            creatureAt: TileCoord(x: 2, y: 2))
        var first = base
        var second = base
        #expect(simulate(&first, seed: 7, limit: 300) == simulate(&second, seed: 7, limit: 300))
        #expect(first.creature == second.creature)
    }

    @Test func restsOnANearbyBenchAndDiscoversItOnce() throws {
        var world = try TestWorlds.grass(objects: [TestWorlds.object(.bench, 4, 3)], creatureAt: TileCoord(x: 1, y: 3))
        let events = simulate(&world, limit: 600)
        #expect(started(events).filter { $0 == .benchRest }.count >= 2)
        #expect(events.filter { $0 == .discovered(.benchRest, by: world.creature.id) }.count == 1)
        #expect(world.discoveries == [.benchRest])
    }

    @Test func aFlowerNextToTheBenchChangesTheReaction() throws {
        var world = try TestWorlds.grass(
            objects: [TestWorlds.object(.bench, 4, 3), TestWorlds.object(.flower, 5, 3)],
            creatureAt: TileCoord(x: 1, y: 3))
        let reactions = Set(started(simulate(&world, limit: 600)))
        #expect(reactions.contains(.bloomBench))
        #expect(!reactions.contains(.benchRest))
    }

    @Test func napsUnderTreesAndVisitsPonds() throws {
        var world = try TestWorlds.grass(
            objects: [TestWorlds.object(.pineTree, 1, 6), TestWorlds.object(.pond, 5, 1)],
            creatureAt: TileCoord(x: 3, y: 3))
        let reactions = Set(started(simulate(&world, limit: 800)))
        #expect(reactions.isSuperset(of: [.treeNap, .pondVisit]))
    }

    @Test func emptyIslandOnlyWanders() throws {
        var world = try TestWorlds.grass(creatureAt: TileCoord(x: 3, y: 3))
        let events = simulate(&world, limit: 300)
        #expect(started(events).isEmpty)
        #expect(events.contains { if case .creatureMoved = $0 { true } else { false } })
    }

    @Test func ignoresObjectsOutsidePerception() throws {
        var world = try TestWorlds.grass(
            width: 16, height: 3, objects: [TestWorlds.object(.bench, 15, 1)], creatureAt: TileCoord(x: 0, y: 1),
            waterColumn: 7)
        #expect(started(simulate(&world, limit: 300)).isEmpty)
    }

    @Test func neverWalksOntoWaterOrObjects() throws {
        var world = try TestWorlds.grass(
            objects: [
                TestWorlds.object(.house, 4, 4), TestWorlds.object(.bench, 1, 6), TestWorlds.object(.flower, 2, 6),
            ],
            creatureAt: TileCoord(x: 1, y: 1), waterColumn: 6)
        var rng = SeededRandom(seed: 99)
        for _ in 0..<1_000 {
            _ = CreatureBrain.step(world: &world, rng: &rng)
            #expect(world.isWalkable(world.creature.position))
        }
    }

    @Test func removingTheTargetInterruptsTheApproach() throws {
        let bench = TestWorlds.object(.bench, 6, 3)
        var world = try TestWorlds.grass(objects: [bench], creatureAt: TileCoord(x: 1, y: 3))
        world.creature.activity = .approaching(
            .benchRest, targetID: bench.id,
            path: [TileCoord(x: 2, y: 3), TileCoord(x: 3, y: 3), TileCoord(x: 4, y: 3), TileCoord(x: 5, y: 3)])
        _ = world.removeObject(bench.id)
        var rng = SeededRandom(seed: 1)
        let events = CreatureBrain.step(world: &world, rng: &rng)
        #expect(events == [.reactionInterrupted(.benchRest, by: world.creature.id)])
        #expect(world.creature.activity == .idle(ticksLeft: 2))
        #expect(world.creature.position == TileCoord(x: 1, y: 3))
    }

    @Test func takingTheFlowerAwayEndsTheBloomReaction() throws {
        let bench = TestWorlds.object(.bench, 4, 3)
        let flower = TestWorlds.object(.flower, 5, 3)
        var world = try TestWorlds.grass(objects: [bench, flower], creatureAt: TileCoord(x: 3, y: 3))
        world.creature.activity = .interacting(.bloomBench, targetID: bench.id, ticksLeft: 5)
        _ = world.removeObject(flower.id)
        var rng = SeededRandom(seed: 1)
        let result1 = CreatureBrain.step(world: &world, rng: &rng)
        #expect(result1 == [.reactionInterrupted(.bloomBench, by: world.creature.id)])
    }

    @Test func cooldownPreventsImmediateRepeat() throws {
        let bench = TestWorlds.object(.bench, 4, 3)
        var world = try TestWorlds.grass(objects: [bench], creatureAt: TileCoord(x: 3, y: 3))
        world.creature.activity = .interacting(.benchRest, targetID: bench.id, ticksLeft: 1)
        var rng = SeededRandom(seed: 3)
        _ = CreatureBrain.step(world: &world, rng: &rng)
        let cooldown = ReactionRule.rule(for: .benchRest).cooldown
        #expect(world.creature.cooldowns[.benchRest] == cooldown)
        var events: [WorldEvent] = []
        for _ in 0..<(cooldown - 2) { events += CreatureBrain.step(world: &world, rng: &rng) }
        #expect(started(events).isEmpty)
    }

    @Test func everyReactionHasExactlyOneRule() {
        for kind in ReactionKind.allCases {
            #expect(ReactionRule.all.filter { $0.kind == kind }.count == 1)
        }
    }
}

@Suite("Path finding")
struct PathFinderTests {
    @Test func findsShortestOrthogonalPath() throws {
        let world = try TestWorlds.grass()
        let path = PathFinder.path(in: world, from: TileCoord(x: 0, y: 0), where: { $0 == TileCoord(x: 2, y: 1) })
        #expect(path?.count == 3)
        #expect(path?.last == TileCoord(x: 2, y: 1))
    }

    @Test func returnsEmptyPathWhenAlreadyThereAndNilWhenUnreachable() throws {
        let world = try TestWorlds.grass(waterColumn: 4)
        #expect(PathFinder.path(in: world, from: TileCoord(x: 1, y: 1), where: { $0 == TileCoord(x: 1, y: 1) }) == [])
        #expect(PathFinder.path(in: world, from: TileCoord(x: 1, y: 1), where: { $0.x > 4 }) == nil)
    }
}
