import Foundation
import Testing

@testable import HibimachiCore

@Suite("Goal steps and plan drafts")
struct GoalStepTests {
    let date = Date(timeIntervalSince1970: 1_800_000_000)

    private func day(_ number: Int) -> LocalDay { LocalDay(year: 2027, month: 1, day: number) }

    private func started(_ category: GoalCategory = .tidy) throws -> (PlayerProgress, Goal) {
        let gift = RewardTransaction(
            id: UUID(), reason: .welcome, xpDelta: 0, sparkleDelta: 30, ruleVersion: 1, date: date)
        var progress = try PlayerProgress(ledger: [gift])
        let goal = try progress.addGoal(title: "部屋", category: category, at: date, makeID: UUID.init).get()
        return (progress, goal)
    }

    private func draft(targets: [Int]) -> PlanDraft {
        PlanDraft(
            steps: targets.enumerated().map { index, target in
                PlanDraft.Step(
                    title: "ステップ\(index)", target: target,
                    quests: [PlanDraft.Quest(title: "クエスト\(index)", minutes: 5)])
            })
    }

    private func complete(_ questID: UUID, _ progress: inout PlayerProgress, on number: Int) throws {
        _ = try progress.complete(questID, on: day(number), at: date, completionID: UUID(), transactionID: UUID())
            .get()
    }

    // MARK: Templates and parsing

    @Test(arguments: GoalCategory.allCases)
    func everyTemplateFitsTheLimitsInBothLanguages(_ category: GoalCategory) throws {
        for language in [QuestPresets.Language.japanese, .english] {
            let template = PlanDraft.template(for: category, language: language)
            #expect(PlanDraft.stepCount.contains(template.steps.count))
            for step in template.steps {
                #expect(step.title.count <= Goal.titleLimit, "\(step.title)")
                #expect(GoalStep.targetRange.contains(step.target))
                #expect(PlanDraft.questsPerStep.contains(step.quests.count))
                for quest in step.quests { #expect(quest.title.count <= Goal.titleLimit, "\(quest.title)") }
            }
            var (progress, goal) = try started(category)
            #expect(progress.applyPlan(template, to: goal.id, makeID: UUID.init).isSuccess)
        }
    }

    @Test func theAIFormatIsReadAndClampedToTheLimits() throws {
        let text = """
            Here is a plan:
            STEP: 机まわりを整える | 10回
            - 机の上を片付ける | 5分
            - ペンを戻す | 3
            STEP: 引き出し | 500
            ・引き出しを1段 | 90分
            - 2つめ
            - 3つめ | 5
            - 4つめは入らない | 5
            step: 説明だけで、クエストのないステップ | 3
            STEP:  | 4
            """
        let plan = try #require(PlanDraft.parse(text))
        #expect(plan.steps.map(\.title) == ["机まわりを整える", "引き出し"], "steps without quests are dropped")
        #expect(plan.steps.map(\.target) == [10, 99])
        #expect(plan.steps[0].quests == [.init(title: "机の上を片付ける", minutes: 5), .init(title: "ペンを戻す", minutes: 3)])
        #expect(plan.steps[1].quests.map(\.minutes) == [60, 5, 5])
        #expect(plan.steps[1].quests.count == PlanDraft.questsPerStep.upperBound)
    }

    @Test func unreadableAnswersGiveNoPlan() {
        #expect(PlanDraft.parse("") == nil)
        #expect(PlanDraft.parse("がんばろう！") == nil)
        #expect(PlanDraft.parse("STEP: ひとつだけ | 3\n- やる | 5") == nil, "one step is not a breakdown")
        let long = String(repeating: "あ", count: 40)
        let cut = PlanDraft.parse("STEP: \(long) | 3\n- \(long)\nSTEP: b | 0\n- c | 0")
        #expect(cut?.steps[0].title.count == Goal.titleLimit)
        #expect(cut?.steps[0].quests[0].minutes == 5, "missing minutes fall back to 5")
        #expect(cut?.steps[1].target == 1 && cut?.steps[1].quests[0].minutes == 1)
    }

    @Test func atMostFiveStepsAreKept() throws {
        let text = (1...7).map { "STEP: s\($0) | 2\n- q\($0) | 5" }.joined(separator: "\n")
        #expect(try #require(PlanDraft.parse(text)).steps.count == PlanDraft.stepCount.upperBound)
    }

    // MARK: Applying and progressing

    @Test func onlyTheCurrentStepAndEverydayQuestsAreSuggested() throws {
        var (progress, goal) = try started()
        let everyday = Set(progress.quests(of: goal.id).map(\.id))
        let steps = try progress.applyPlan(draft(targets: [2, 3]), to: goal.id, makeID: UUID.init).get()
        #expect(progress.currentStep(of: goal.id) == steps[0])
        let first = try #require(progress.quests.first { $0.stepID == steps[0].id })
        let second = try #require(progress.quests.first { $0.stepID == steps[1].id })
        #expect(Set(progress.suggestableQuests(of: goal.id).map(\.id)) == everyday.union([first.id]))

        try complete(first.id, &progress, on: 1)
        #expect(progress.stepStatuses(of: goal.id)[0].done == 1)
        #expect(progress.stepStatuses(of: goal.id)[0].fraction == 0.5)
        try complete(first.id, &progress, on: 2)
        #expect(progress.currentStep(of: goal.id) == steps[1])
        #expect(progress.suggestableQuests(of: goal.id).contains { $0.id == second.id })
        #expect(!progress.suggestableQuests(of: goal.id).contains { $0.id == first.id })
        #expect(DailyPlanner.suggestions(for: day(3), in: progress).allSatisfy { $0.id != first.id })
        #expect(!progress.isPlanFinished(goal.id))
        for number in 3...5 { try complete(second.id, &progress, on: number) }
        #expect(progress.isPlanFinished(goal.id))
        #expect(progress.currentStep(of: goal.id) == nil)
        #expect(Set(progress.suggestableQuests(of: goal.id).map(\.id)) == everyday, "everyday quests stay")
    }

    @Test func undoingACompletionMovesTheStepBack() throws {
        var (progress, goal) = try started()
        let steps = try progress.applyPlan(draft(targets: [1, 1]), to: goal.id, makeID: UUID.init).get()
        let first = try #require(progress.quests.first { $0.stepID == steps[0].id })
        let completionID = UUID()
        _ = try progress.complete(first.id, on: day(1), at: date, completionID: completionID, transactionID: UUID())
            .get()
        #expect(progress.currentStep(of: goal.id) == steps[1])
        _ = try progress.undoCompletion(completionID, today: day(1), at: date, transactionID: UUID()).get()
        #expect(progress.currentStep(of: goal.id) == steps[0])
    }

    @Test func replanningKeepsHistoryAndDropsUnusedQuests() throws {
        var (progress, goal) = try started()
        let old = try progress.applyPlan(draft(targets: [3, 3]), to: goal.id, makeID: UUID.init).get()
        let used = try #require(progress.quests.first { $0.stepID == old[0].id })
        let unused = try #require(progress.quests.first { $0.stepID == old[1].id })
        try complete(used.id, &progress, on: 1)
        let new = try progress.applyPlan(draft(targets: [5, 5, 5]), to: goal.id, makeID: UUID.init).get()
        #expect(progress.steps(of: goal.id) == new)
        let kept = try #require(progress.quests.first { $0.id == used.id })
        #expect(kept.isRetired && kept.stepID == nil, "history stays; it is no longer suggested")
        #expect(!progress.quests.contains { $0.id == unused.id })
        #expect(progress.stepStatuses(of: goal.id).allSatisfy { $0.done == 0 })
    }

    @Test func badPlansChangeNothing() throws {
        var (progress, goal) = try started()
        let before = progress
        #expect(progress.applyPlan(draft(targets: [3]), to: goal.id, makeID: UUID.init) == .failure(.invalidPlan))
        #expect(progress.applyPlan(draft(targets: [3, 0]), to: goal.id, makeID: UUID.init) == .failure(.invalidPlan))
        var noQuests = draft(targets: [3, 3])
        noQuests.steps[1].quests = []
        #expect(progress.applyPlan(noQuests, to: goal.id, makeID: UUID.init) == .failure(.invalidPlan))
        var blank = draft(targets: [3, 3])
        blank.steps[0].title = "  "
        #expect(progress.applyPlan(blank, to: goal.id, makeID: UUID.init) == .failure(.emptyTitle))
        var slow = draft(targets: [3, 3])
        slow.steps[0].quests[0].minutes = 61
        #expect(progress.applyPlan(slow, to: goal.id, makeID: UUID.init) == .failure(.invalidMinutes))
        let stranger = UUID()
        #expect(
            progress.applyPlan(draft(targets: [3, 3]), to: stranger, makeID: UUID.init)
                == .failure(.unknownGoal(stranger)))
        #expect(progress == before)
        _ = progress.archiveGoal(goal.id)
        #expect(
            progress.applyPlan(draft(targets: [3, 3]), to: goal.id, makeID: UUID.init)
                == .failure(.goalArchived(goal.id)))
    }

    @Test func savedStepsMustPointAtTheirGoal() throws {
        let goal = Goal(id: UUID(), title: "a", category: .tidy, createdAt: date)
        let other = Goal(id: UUID(), title: "b", category: .rest, createdAt: date)
        let step = GoalStep(id: UUID(), goalID: goal.id, title: "s", target: 3)
        let crossed = QuestTemplate(id: UUID(), goalID: other.id, title: "q", minutes: 5, stepID: step.id)
        #expect(throws: ProgressError.invalidPlan) {
            try PlayerProgress(goals: [goal, other], quests: [crossed], steps: [step])
        }
        let orphan = GoalStep(id: UUID(), goalID: UUID(), title: "s", target: 3)
        #expect(throws: ProgressError.unknownGoal(orphan.goalID)) { try PlayerProgress(goals: [goal], steps: [orphan]) }
        let zero = GoalStep(id: UUID(), goalID: goal.id, title: "s", target: 0)
        #expect(throws: ProgressError.invalidPlan) { try PlayerProgress(goals: [goal], steps: [zero]) }
    }

    @MainActor
    @Test func theStoreAppliesAPlanAndTodaysQuestsFollowIt() throws {
        let repository = FakeRepository(.loaded(snapshot(try TestWorlds.grass())))
        let store = GameStore(repository: repository, seed: 1, now: { date })
        #expect(store.addGoal(title: "部屋", category: .tidy))
        let goal = try #require(store.progress.activeGoals.first)
        #expect(store.applyPlan(PlanDraft.template(for: .tidy), to: goal.id))
        let current = try #require(store.progress.currentStep(of: goal.id))
        #expect(store.todaysQuests.allSatisfy { $0.stepID == nil || $0.stepID == current.id })
        #expect(!store.applyPlan(draft(targets: [1]), to: goal.id))
        #expect(store.lastProgressError == .invalidPlan)
        #expect(repository.saved.last?.progress.steps(of: goal.id).count == 3)
    }
}

extension Result {
    fileprivate var isSuccess: Bool { if case .success = self { true } else { false } }
}
