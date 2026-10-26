import Foundation
import Testing

@testable import HibimachiCore

@Suite("Friendship with residents")
struct FriendshipTests {
    let day = LocalDay(year: 2027, month: 1, day: 15)

    @Test func pettingCountsAFewTimesADayAndNeverGoesDown() {
        var bond = Friendship()
        #expect(bond.level == .new && bond.pointsToNextLevel == Friendship.Level.friend.threshold)
        let counted = (0..<Friendship.petsPerDay).map { _ in bond.pet(on: day) }
        #expect(counted.allSatisfy { $0 })
        let extra = bond.pet(on: day)
        #expect(!extra, "today's pets are used up")
        #expect(bond.points == Friendship.petsPerDay)
        let tomorrow = bond.pet(on: day.next)
        #expect(tomorrow, "a new day counts again")
        #expect(bond.points == Friendship.petsPerDay + 1)
    }

    @Test func levelsFollowThePoints() {
        #expect(Friendship(points: 5).level == .new)
        #expect(Friendship(points: 6).level == .friend)
        #expect(Friendship(points: 19).level == .friend)
        #expect(Friendship(points: 20).level == .bestFriend)
        #expect(Friendship(points: 20).pointsToNextLevel == nil)
        #expect(Friendship(points: -4).points == 0, "a tampered value cannot go below zero")
        #expect(Friendship(points: 0, petDay: day, petsOnPetDay: 99).petsOnPetDay == Friendship.petsPerDay)
    }

    @MainActor
    @Test func thePlayerCanPetResidentsAndLevelUpsAreAnnounced() throws {
        let repository = FakeRepository(.loaded(snapshot(try TestWorlds.grass())))
        let store = GameStore(
            repository: repository, seed: 1, now: { Date(timeIntervalSince1970: 1_800_000_000) })
        let mochi = store.world.creature.id
        let stranger = store.pet(UUID())
        #expect(stranger == .unknownResident)
        // Fill the first level with discoveries credited to this resident, then pet across it.
        for _ in 0..<2 { _ = store.creditDiscovery(by: mochi) }
        #expect(store.world.creature.friendship.points == 4)
        let outcomes = (0..<4).map { _ in store.pet(mochi) }
        #expect(outcomes[0] == .counted(.new, leveledUp: false))
        #expect(outcomes[1] == .counted(.friend, leveledUp: true))
        #expect(store.pendingFriendships == [FriendshipNotice(species: .mochi, level: .friend)])
        #expect(repository.saved.last?.world.creature.friendship.points == 7)
        #expect(outcomes[2] == .counted(.friend, leveledUp: false))
        #expect(outcomes[3] == .notCounted(.friend))
        store.dismissFriendship()
        #expect(store.pendingFriendships.isEmpty)
    }

    @MainActor
    @Test func discoveriesBringTheResidentWhoMadeThemCloser() throws {
        let world = try TestWorlds.grass(
            objects: [TestWorlds.object(.bench, 4, 4)], creatureAt: TileCoord(x: 3, y: 3))
        let store = GameStore(repository: FakeRepository(.loaded(snapshot(world))), seed: 3)
        var discovered = false
        for _ in 0..<600 where !discovered {
            discovered = store.tick().contains { if case .discovered = $0 { true } else { false } }
        }
        #expect(discovered)
        #expect(store.world.creature.friendship.points == Friendship.pointsPerDiscovery)
    }

    @MainActor
    @Test func undoDoesNotTakeFriendshipBack() throws {
        let store = GameStore(repository: FakeRepository(.loaded(snapshot(try TestWorlds.grass()))), seed: 1)
        #expect(store.beginPlacing(.flower))
        #expect(store.confirmPreview())
        _ = store.pet(store.world.creature.id)
        store.undo()
        #expect(store.world.creature.friendship.points == 1)
    }
}
