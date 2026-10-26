import Foundation
import Testing

@testable import HibimachiCore

@Suite("Time-of-day discoveries")
struct TimeOfDayTests {
    private func started(in world: World, phase: DayPhase, seed: UInt64 = 7) -> Set<ReactionKind> {
        var copy = world
        var kinds = Set<ReactionKind>()
        for event in simulate(&copy, seed: seed, phase: phase, limit: 1_200) {
            if case .reactionStarted(let kind, _, _) = event { kinds.insert(kind) }
        }
        return kinds
    }

    @Test func firefliesAppearOnlyAtNightAtAPondWithFlowers() throws {
        let world = try TestWorlds.grass(
            objects: [TestWorlds.object(.pond, 4, 4), TestWorlds.object(.flower, 6, 4)],
            creatureAt: TileCoord(x: 3, y: 3))
        #expect(!started(in: world, phase: .day).contains(.fireflies))
        #expect(started(in: world, phase: .night).contains(.fireflies))

        let bare = try TestWorlds.grass(objects: [TestWorlds.object(.pond, 4, 4)], creatureAt: TileCoord(x: 3, y: 3))
        #expect(!started(in: bare, phase: .night).contains(.fireflies), "no flowers, no fireflies")
    }

    @Test func aBlanketMeansAPicnicByDayAndStargazingAtNightUnderAnOpenSky() throws {
        let open = try TestWorlds.grass(
            objects: [TestWorlds.object(.picnicMat, 4, 4)], creatureAt: TileCoord(x: 3, y: 3))
        #expect(started(in: open, phase: .night).contains(.stargazing))
        #expect(!started(in: open, phase: .day).contains(.stargazing))

        let shaded = try TestWorlds.grass(
            objects: [TestWorlds.object(.picnicMat, 4, 4), TestWorlds.object(.roundTree, 5, 5)],
            creatureAt: TileCoord(x: 3, y: 3))
        let night = started(in: shaded, phase: .night)
        #expect(!night.contains(.stargazing) && !night.contains(.picnic), "trees hide the stars; no picnic at night")
        #expect(started(in: shaded, phase: .day).contains(.picnic))
    }

    @Test func eachSpotHasOneMeaningAtATime() throws {
        let fire = TestWorlds.object(.campfire, 4, 4)
        var world = try TestWorlds.grass(objects: [fire])
        let warm = ReactionRule.rule(for: .campfireWarm)
        let circle = ReactionRule.rule(for: .campfireCircle)
        #expect(warm.accepts(fire, in: world) && !circle.accepts(fire, in: world))
        _ = world.place(.bench, at: TileCoord(x: 5, y: 4), id: UUID())
        #expect(!warm.accepts(fire, in: world) && circle.accepts(fire, in: world))
        #expect(!circle.canStart(during: .day) && circle.canStart(during: .evening))

        let peek = ReactionRule.rule(for: .wellPeek)
        let water = ReactionRule.rule(for: .morningWater)
        for phase in DayPhase.allCases {
            #expect(peek.canStart(during: phase) != water.canStart(during: phase), "\(phase)")
        }
    }

    @Test func everyTimeOfDayHasSomethingToFind() {
        let limitedRules = ReactionRule.all.filter { $0.phases.count < DayPhase.allCases.count }
        for phase in [DayPhase.morning, .evening, .night] {
            #expect(limitedRules.contains { $0.canStart(during: phase) }, "\(phase) has its own discovery")
        }
        let limited = ReactionRule.all.filter { $0.phases.count < DayPhase.allCases.count }.map(\.kind)
        #expect(Set(limited).isSuperset(of: [.fireflies, .lampGlow, .stargazing, .campfireCircle, .morningWater]))
    }

    @MainActor
    @Test func theStoreUsesTheTimeOfDayItIsGiven() throws {
        let world = try TestWorlds.grass(
            objects: [TestWorlds.object(.pond, 4, 4), TestWorlds.object(.flower, 6, 4)],
            creatureAt: TileCoord(x: 3, y: 3))
        let store = GameStore(repository: FakeRepository(.loaded(snapshot(world))), seed: 7)
        store.dayPhase = .night
        var seen = Set<ReactionKind>()
        for _ in 0..<1_200 {
            for case .reactionStarted(let kind, _, _) in store.tick() { seen.insert(kind) }
        }
        #expect(seen.contains(.fireflies))
    }
}
