import Foundation
import Testing

@testable import HibimachiCore

@Suite("Editing goals and quests")
struct GoalEditingTests {
    let date = Date(timeIntervalSince1970: 1_800_000_000)
    let day = LocalDay(year: 2027, month: 1, day: 15)

    private func started() throws -> (PlayerProgress, Goal) {
        let gift = RewardTransaction(
            id: UUID(), reason: .welcome, xpDelta: 0, sparkleDelta: 30, ruleVersion: 1, date: date)
        var progress = try PlayerProgress(ledger: [gift])
        let goal = try progress.addGoal(title: "部屋", category: .tidy, at: date, makeID: UUID.init).get()
        return (progress, goal)
    }

    @Test func goalsCanBeRenamedWithTheSameRulesAsNewOnes() throws {
        var (progress, goal) = try started()
        #expect((try? progress.renameGoal(goal.id, to: "  心地よい部屋 ").get())?.title == "心地よい部屋")
        #expect(progress.renameGoal(goal.id, to: " ") == .failure(.emptyTitle))
        #expect(
            progress.renameGoal(goal.id, to: String(repeating: "あ", count: 31)) == .failure(.titleTooLong(limit: 30)))
        let stranger = UUID()
        #expect(progress.renameGoal(stranger, to: "x") == .failure(.unknownGoal(stranger)))
        #expect(progress.goals.first?.title == "心地よい部屋")
    }

    @Test func aRestingGoalComesBackOnlyIfThereIsRoom() throws {
        var (progress, goal) = try started()
        _ = progress.archiveGoal(goal.id)
        for index in 0..<3 {
            _ = try progress.addGoal(title: "目標\(index)", category: .rest, at: date, makeID: UUID.init).get()
        }
        #expect(progress.resumeGoal(goal.id) == .failure(.tooManyGoals(limit: 3)))
        _ = progress.archiveGoal(progress.activeGoals[0].id)
        #expect((try? progress.resumeGoal(goal.id).get())?.isArchived == false)
        #expect(progress.activeGoals.contains { $0.id == goal.id })
    }

    @Test func editingAQuestKeepsPastRewardsAsTheyWere() throws {
        var (progress, goal) = try started()
        let quest = try #require(progress.quests(of: goal.id).first)
        let reward = try progress.complete(quest.id, on: day, at: date, completionID: UUID(), transactionID: UUID())
            .get()
        let edited = try progress.editQuest(quest.id, title: "机を拭く", minutes: 30).get()
        #expect(edited.title == "机を拭く" && edited.minutes == 30)
        #expect(progress.totalXP == reward.xpDelta, "the ledger is history")
        #expect(progress.editQuest(quest.id, title: "x", minutes: 0) == .failure(.invalidMinutes))
        #expect(progress.editQuest(quest.id, title: "", minutes: 5) == .failure(.emptyTitle))
        #expect(progress.editQuest(UUID(), title: "x", minutes: 5).isFailure)
    }

    @Test func removingAQuestDeletesItUnlessHistoryPointsAtIt() throws {
        var (progress, goal) = try started()
        let quests = progress.quests(of: goal.id)
        _ = try progress.complete(quests[0].id, on: day, at: date, completionID: UUID(), transactionID: UUID()).get()
        #expect((try? progress.removeQuest(quests[0].id).get()) != nil)
        #expect((try? progress.removeQuest(quests[1].id).get()) != nil)
        #expect(progress.quests(of: goal.id).map(\.id) == [quests[0].id, quests[2].id], "the done one stays")
        #expect(progress.quests(of: goal.id).first?.isRetired == true)
        #expect(progress.activeQuests(of: goal.id).map(\.id) == [quests[2].id])
        for later in 1...10 {
            let suggested = DailyPlanner.suggestions(for: LocalDay(year: 2027, month: 2, day: later), in: progress)
            #expect(suggested.map(\.id) == [quests[2].id], "retired quests are never suggested")
        }
        // The completion history still finds its quest, so the save stays valid.
        #expect(throws: Never.self) {
            try PlayerProgress(
                goals: progress.goals, quests: progress.quests, completions: progress.completions,
                ledger: progress.ledger, owned: progress.owned)
        }
    }

    @MainActor
    @Test func theStoreSavesEditsAndExplainsRefusals() throws {
        let repository = FakeRepository(.loaded(snapshot(try TestWorlds.grass())))
        let store = GameStore(repository: repository, seed: 1, now: { date })
        #expect(store.addGoal(title: "学ぶ", category: .study))
        let goal = try #require(store.progress.activeGoals.first)
        #expect(store.renameGoal(goal.id, to: "英語を学ぶ"))
        #expect(repository.saved.last?.progress.goals.first?.title == "英語を学ぶ")
        #expect(!store.renameGoal(goal.id, to: ""))
        #expect(store.lastProgressError == .emptyTitle)
        let quest = try #require(store.progress.quests(of: goal.id).first)
        #expect(store.editQuest(quest.id, title: "単語を3つ", minutes: 5))
        #expect(store.removeQuest(quest.id))
        #expect(store.progress.quests(of: goal.id).count == 2)
    }
}

extension Result {
    fileprivate var isFailure: Bool { if case .failure = self { true } else { false } }
}
