import Foundation
import Testing

@testable import HibimachiCore

@Suite("Goal towers and the island's mood")
struct IslandLookTests {
    let date = Date(timeIntervalSince1970: 1_800_000_000)
    let today = LocalDay(year: 2027, month: 3, day: 31)

    private func plan(_ targets: [Int]) -> PlanDraft {
        PlanDraft(
            steps: targets.enumerated().map { index, target in
                PlanDraft.Step(title: "s\(index)", target: target, quests: [.init(title: "q\(index)", minutes: 5)])
            })
    }

    private func complete(
        _ questID: UUID, _ progress: inout PlayerProgress, on day: LocalDay
    ) throws {
        _ = try progress.complete(questID, on: day, at: date, completionID: UUID(), transactionID: UUID()).get()
    }

    @Test func aTowerGrowsWithFinishedStepsAndIsCompleteAtTheEnd() throws {
        var progress = try PlayerProgress()
        let goal = try progress.addGoal(title: "部屋", category: .tidy, at: date, makeID: UUID.init).get()
        #expect(GoalMonument.all(in: progress).map(\.stage) == [0], "no steps: only the foundation")
        let steps = try progress.applyPlan(plan([1, 1, 1, 1]), to: goal.id, makeID: UUID.init).get()
        #expect(GoalMonument.all(in: progress).first?.stage == 1)
        var expected = [1, 1, 2, 3, 4]
        for (index, step) in steps.enumerated() {
            let quest = try #require(progress.quests.first { $0.stepID == step.id })
            try complete(quest.id, &progress, on: LocalDay(year: 2027, month: 1, day: 1 + index))
            expected.removeFirst()
            #expect(GoalMonument.all(in: progress).first?.stage == expected.first, "after step \(index)")
        }
        #expect(GoalMonument.all(in: progress).first?.stage == GoalMonument.maxStage)
    }

    @Test func towersFollowTheOrderGoalsWereMadeAndSkipRestingOnes() throws {
        var progress = try PlayerProgress()
        let first = try progress.addGoal(title: "a", category: .study, at: date, makeID: UUID.init).get()
        let second = try progress.addGoal(
            title: "b", category: .move, at: date.addingTimeInterval(1), makeID: UUID.init
        ).get()
        #expect(GoalMonument.all(in: progress).map(\.goalID) == [first.id, second.id])
        _ = progress.archiveGoal(first.id)
        #expect(GoalMonument.all(in: progress).map(\.goalID) == [second.id])
        #expect(GoalMonument.all(in: try PlayerProgress()).isEmpty)
    }

    @Test func theMoodLeansOnlyWithEnoughRecentActivity() throws {
        var progress = try PlayerProgress()
        let study = try progress.addGoal(title: "学ぶ", category: .study, at: date, makeID: UUID.init).get()
        let move = try progress.addGoal(title: "動く", category: .move, at: date, makeID: UUID.init).get()
        let studyQuest = try #require(progress.quests(of: study.id).first)
        let moveQuest = try #require(progress.quests(of: move.id).first)
        for offset in 0..<4 {
            try complete(studyQuest.id, &progress, on: LocalDay(year: 2027, month: 3, day: 20 + offset))
        }
        #expect(IslandMood.leaning(in: progress, today: today) == nil, "fewer than five completions")
        try complete(studyQuest.id, &progress, on: LocalDay(year: 2027, month: 3, day: 30))
        #expect(IslandMood.leaning(in: progress, today: today) == .study)
        for offset in 0..<5 {
            try complete(moveQuest.id, &progress, on: LocalDay(year: 2027, month: 3, day: 20 + offset))
        }
        #expect(IslandMood.leaning(in: progress, today: today) == .study, "a tie keeps the first category")
        for offset in 0..<3 {
            try complete(moveQuest.id, &progress, on: LocalDay(year: 2027, month: 3, day: 25 + offset))
        }
        #expect(IslandMood.leaning(in: progress, today: today) == .move)
        // Six weeks later nothing is recent any more.
        #expect(IslandMood.leaning(in: progress, today: LocalDay(year: 2027, month: 5, day: 15)) == nil)
    }

    @Test func noCategoryLeadsWhenActivityIsSpread() throws {
        var progress = try PlayerProgress()
        for (index, category) in [GoalCategory.tidy, .study, .rest].enumerated() {
            let goal = try progress.addGoal(title: "g\(index)", category: category, at: date, makeID: UUID.init).get()
            let quest = try #require(progress.quests(of: goal.id).first)
            for offset in 0..<2 {
                try complete(quest.id, &progress, on: LocalDay(year: 2027, month: 3, day: 10 + offset))
            }
        }
        #expect(IslandMood.leaning(in: progress, today: today) == nil, "2 of 6 is under 40%")
    }

    @Test func daysAreCountedAcrossMonthsAndYears() {
        #expect(LocalDay(year: 2027, month: 3, day: 1).daysSince(LocalDay(year: 2027, month: 2, day: 28)) == 1)
        #expect(LocalDay(year: 2028, month: 1, day: 1).daysSince(LocalDay(year: 2027, month: 12, day: 31)) == 1)
        #expect(LocalDay(year: 2027, month: 1, day: 1).daysSince(LocalDay(year: 2027, month: 1, day: 3)) == -2)
    }

    @MainActor
    @Test func finishingAStepIsAnnouncedOnce() throws {
        let repository = FakeRepository(.loaded(snapshot(try TestWorlds.grass())))
        let store = GameStore(repository: repository, seed: 1, now: { date })
        #expect(store.addGoal(title: "部屋", category: .tidy))
        let goal = try #require(store.progress.activeGoals.first)
        #expect(store.applyPlan(plan([1, 2]), to: goal.id))
        let steps = store.progress.steps(of: goal.id)
        let first = try #require(store.progress.quests.first { $0.stepID == steps[0].id })
        let everyday = try #require(store.progress.quests.first { $0.goalID == goal.id && $0.stepID == nil })
        #expect(store.completeQuest(everyday.id))
        #expect(store.pendingStepFinishes.isEmpty, "everyday quests do not finish steps")
        #expect(store.completeQuest(first.id))
        #expect(store.pendingStepFinishes == [StepFinished(goalTitle: "部屋", stepTitle: "s0", completesGoal: false)])
        store.dismissStepFinished()
        #expect(store.pendingStepFinishes.isEmpty)
    }
}
