import Foundation
import Testing

@testable import HibimachiCore

@MainActor
@Suite("GameStore economy and quests")
struct GameStoreEconomyTests {
    private func store(sparkles: Int, objects: [WorldObject] = []) throws -> (GameStore, FakeRepository) {
        let repository = FakeRepository(.loaded(snapshot(try TestWorlds.grass(objects: objects), sparkles: sparkles)))
        let date = Date(timeIntervalSince1970: 1_800_000_000)
        return (GameStore(repository: repository, seed: 1, now: { date }), repository)
    }

    @Test func placingWithoutStockBuysAfterValidation() throws {
        let tree = TestWorlds.object(.roundTree, 2, 2)
        let (store, _) = try store(sparkles: 12, objects: [tree])
        #expect(store.available(.flower) == 0)
        store.beginPlacing(.flower)
        store.setPreviewOrigin(tree.origin)
        #expect(!store.confirmPreview())  // blocked spot: nothing is spent
        #expect(store.progress.sparkles == 12)
        store.setPreviewOrigin(TileCoord(x: 5, y: 5))
        #expect(store.confirmPreview())
        #expect(store.progress.sparkles == 7)
        #expect(store.progress.owned[.flower] == 1)
    }

    @Test func unaffordableKindsCannotStartPlacing() throws {
        let (store, _) = try store(sparkles: 5)
        #expect(!store.canPlaceOrBuy(.house))
        #expect(!store.beginPlacing(.house))
        #expect(store.mode == .browse)
        #expect(store.canPlaceOrBuy(.flower))
    }

    @Test func puttingAwayKeepsItInStorageForFree() throws {
        let bench = TestWorlds.object(.bench, 1, 1)
        let (store, _) = try store(sparkles: 0, objects: [bench])
        store.select(bench.id)
        store.removeSelection()
        #expect(store.available(.bench) == 1)
        store.beginPlacing(.bench)
        #expect(store.confirmPreview())
        #expect(store.progress.sparkles == 0)
        // Undoing the placement returns it to storage; the earlier purchase is not charged again.
        store.undo()
        #expect(store.available(.bench) == 1)
    }

    @Test func completingAQuestRewardsAndCanBeUndone() throws {
        let (store, repository) = try store(sparkles: 0)
        #expect(store.addGoal(title: "片付け", category: .tidy))
        let quest = try #require(store.todaysQuests.first)
        #expect(store.completeQuest(quest.id))
        #expect(store.progress.sparkles == RewardRule.questSparkles)
        #expect(store.lastCompletion != nil)
        #expect(repository.saved.last?.progress.totalXP == RewardRule.questXP)
        #expect(!store.todaysQuests.contains { $0.id == quest.id })

        #expect(store.undoLastCompletion())
        #expect(store.progress.sparkles == 0 && store.progress.totalXP == 0)
        #expect(store.lastCompletion == nil)
        #expect(!store.undoLastCompletion())
    }

    @Test func refusalsExplainWhy() throws {
        let (store, _) = try store(sparkles: 0)
        #expect(!store.addGoal(title: "", category: .rest))
        #expect(store.lastProgressError == .emptyTitle)
        #expect(store.addGoal(title: "休む", category: .rest))
        #expect(store.lastProgressError == nil)
    }

    @Test func resettingTheIslandKeepsEverythingEarned() throws {
        let (store, _) = try store(sparkles: 40)
        store.addGoal(title: "動く", category: .move)
        store.beginPlacing(.pond)
        #expect(store.confirmPreview())
        let before = store.progress
        store.resetIsland()
        #expect(store.progress.sparkles == before.sparkles)
        #expect(store.progress.goals == before.goals)
        #expect(store.progress.owned[.pond, default: 0] >= 1)
    }
}
