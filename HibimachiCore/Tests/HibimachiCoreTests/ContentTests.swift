import Foundation
import Testing

@testable import HibimachiCore

@Suite("v1.0 content: unlocks, reactions and residents")
struct ContentTests {
    @Test func everyKindHasAPriceAndAnUnlockAndEveryReactionARule() {
        for kind in ObjectKind.allCases {
            #expect(RewardRule.price(of: kind) > 0)
            #expect(Unlocks.requirement(for: kind).level >= 1)
        }
        #expect(Set(ReactionRule.all.map(\.kind)) == Set(ReactionKind.allCases))
        #expect(ReactionKind.allCases.count == 20)
    }

    @Test func kindsUnlockByLevelOrByDiscoveries() {
        #expect(Unlocks.isUnlocked(.house, level: 1, discoveries: 0))
        #expect(!Unlocks.isUnlocked(.cafe, level: 3, discoveries: 8))
        #expect(Unlocks.isUnlocked(.cafe, level: 4, discoveries: 0), "quests reach it")
        #expect(Unlocks.isUnlocked(.cafe, level: 1, discoveries: 9), "playing the island alone reaches it too")
    }

    @MainActor
    @Test func lockedKindsCannotBeBoughtButOwnedOnesCanBePlaced() throws {
        let store = GameStore(
            repository: FakeRepository(.loaded(snapshot(try TestWorlds.grass(), sparkles: 1_000))), seed: 1)
        #expect(!store.isUnlocked(.fountain))
        #expect(!store.canPlaceOrBuy(.fountain))
        #expect(!store.beginPlacing(.fountain))
        #expect(store.canPlaceOrBuy(.rock))
    }

    @Test func comboReactionsNeedTheirNeighbour() throws {
        let mat = TestWorlds.object(.picnicMat, 4, 4)
        let cafe = TestWorlds.object(.cafe, 1, 1)
        var world = try TestWorlds.grass(objects: [mat, cafe])
        let picnic = ReactionRule.rule(for: .picnic)
        let terrace = ReactionRule.rule(for: .cafeTerrace)
        let visit = ReactionRule.rule(for: .cafeVisit)
        #expect(!picnic.accepts(mat, in: world))
        #expect(visit.accepts(cafe, in: world) && !terrace.accepts(cafe, in: world))
        _ = world.place(.sakuraTree, at: TileCoord(x: 5, y: 5), id: UUID())
        _ = world.place(.bench, at: TileCoord(x: 3, y: 2), id: UUID())
        #expect(picnic.accepts(mat, in: world), "a diagonal tree counts as shade")
        #expect(terrace.accepts(cafe, in: world) && !visit.accepts(cafe, in: world))
    }

    @Test func newcomersArriveOnceAsTheIslandGetsLivelier() throws {
        var world = try TestWorlds.grass()
        #expect(world.welcomeResidentsIfDue(makeID: UUID.init).isEmpty)
        for kind in [ReactionKind.benchRest, .treeNap, .pondVisit] { world.recordDiscovery(kind) }
        let arrived = world.welcomeResidentsIfDue(makeID: UUID.init)
        #expect(arrived.map(\.species) == [.kotori])
        #expect(world.welcomeResidentsIfDue(makeID: UUID.init).isEmpty, "never twice")
        #expect(world.residents.count == 2)
        #expect(world.residents[1].position != world.creature.position)
        #expect(world.isWalkable(world.residents[1].position))
    }

    @Test func everyResidentActsAndPreferencesTiltTheirChoices() throws {
        let birdhouse = TestWorlds.object(.birdhouse, 5, 5)
        let tree = TestWorlds.object(.roundTree, 6, 6)
        let bench = TestWorlds.object(.bench, 2, 5)
        var world = try TestWorlds.grass(objects: [birdhouse, tree, bench], creatureAt: TileCoord(x: 4, y: 4))
        let bird = Creature(id: UUID(), species: .kotori, position: TileCoord(x: 4, y: 5))
        world.residents.append(bird)
        var started: [UUID: [ReactionKind]] = [:]
        for event in simulate(&world, seed: 11, limit: 1_500) {
            if case .reactionStarted(let kind, _, let who) = event { started[who, default: []].append(kind) }
        }
        let birdChoices = started[bird.id] ?? []
        let mochiChoices = started[world.creature.id] ?? []
        #expect(!birdChoices.isEmpty && !mochiChoices.isEmpty, "both residents move and react")
        let birdWatching = birdChoices.filter { $0 == .birdWatch }.count
        let mochiWatching = mochiChoices.filter { $0 == .birdWatch }.count
        #expect(birdWatching > mochiWatching, "the bird prefers the birdhouse")
    }

    @Test func placingOnAResidentMovesEveryoneOffTheTile() throws {
        var world = try TestWorlds.grass(creatureAt: TileCoord(x: 3, y: 3))
        world.residents.append(Creature(id: UUID(), species: .tanuki, position: TileCoord(x: 4, y: 3)))
        _ = world.place(.cafe, at: TileCoord(x: 3, y: 3), id: UUID())
        #expect(world.residents.allSatisfy { world.isWalkable($0.position) })
    }

    @MainActor
    @Test func storeAnnouncesNewcomersAndResetKeepsOnlyTheFirstResident() throws {
        var game = snapshot(try TestWorlds.grass())
        for kind in [ReactionKind.benchRest, .treeNap, .pondVisit] { game.world.recordDiscovery(kind) }
        let repository = FakeRepository(.loaded(game))
        let store = GameStore(repository: repository, seed: 3)
        let events = store.tick()
        #expect(events.contains { if case .residentArrived(.kotori, _) = $0 { true } else { false } })
        #expect(store.pendingArrivals == [.kotori])
        #expect(repository.saved.last?.world.residents.count == 2)
        store.dismissArrival()
        #expect(store.pendingArrivals.isEmpty)
        store.resetIsland()
        #expect(store.world.residents.count == 1)
    }
}
