import Foundation
import Testing

@testable import HibimachiCore

@Suite("Goals, quests and rewards")
struct PlayerProgressTests {
    let date = Date(timeIntervalSince1970: 1_800_000_000)
    let day = LocalDay(year: 2027, month: 1, day: 15)

    private func started(sparkles: Int = RewardRule.welcomeSparkles) throws -> PlayerProgress {
        let gift = RewardTransaction(
            id: UUID(), reason: .welcome, xpDelta: 0, sparkleDelta: sparkles, ruleVersion: 1, date: date)
        return try PlayerProgress(ledger: [gift])
    }

    @Test func newGoalGetsPresetQuests() throws {
        var progress = try started()
        let goal = try progress.addGoal(title: "  部屋を整える ", category: .tidy, at: date, makeID: UUID.init).get()
        #expect(goal.title == "部屋を整える")
        #expect(progress.quests(of: goal.id).count == QuestPresets.quests(for: .tidy).count)
    }

    @Test func goalTitleAndCountAreLimited() throws {
        var progress = try started()
        let empty = progress.addGoal(title: "   ", category: .rest, at: date, makeID: UUID.init)
        #expect(empty == .failure(.emptyTitle))
        let long = progress.addGoal(
            title: String(repeating: "あ", count: 31), category: .rest, at: date, makeID: UUID.init)
        #expect(long == .failure(.titleTooLong(limit: Goal.titleLimit)))
        for index in 0..<3 {
            _ = try progress.addGoal(title: "目標\(index)", category: .other, at: date, makeID: UUID.init).get()
        }
        let fourth = progress.addGoal(title: "多すぎ", category: .other, at: date, makeID: UUID.init)
        #expect(fourth == .failure(.tooManyGoals(limit: 3)))
        // Archiving frees a slot without deleting history.
        let first = progress.activeGoals[0]
        _ = progress.archiveGoal(first.id)
        let replacement = progress.addGoal(title: "新しい目標", category: .move, at: date, makeID: UUID.init)
        #expect((try? replacement.get()) != nil)
        #expect(progress.goals.count == 4)
    }

    @Test func completionRewardsExactlyOnce() throws {
        var progress = try started()
        let goal = try progress.addGoal(title: "学ぶ", category: .study, at: date, makeID: UUID.init).get()
        let quest = try #require(progress.quests(of: goal.id).first)
        let completionID = UUID()
        let reward = try progress.complete(
            quest.id, on: day, at: date, completionID: completionID, transactionID: UUID()
        ).get()
        #expect(reward.xpDelta == RewardRule.questXP && reward.sparkleDelta == RewardRule.questSparkles)
        #expect(progress.sparkles == RewardRule.welcomeSparkles + RewardRule.questSparkles)

        // Replaying the same event (same completion ID) or completing again today grants nothing.
        let replay = progress.complete(
            quest.id, on: day.next, at: date, completionID: completionID, transactionID: UUID())
        #expect(replay == .failure(.alreadyRewarded(completionID)))
        let again = progress.complete(quest.id, on: day, at: date, completionID: UUID(), transactionID: UUID())
        #expect(again == .failure(.alreadyCompletedToday(quest.id)))
        #expect(progress.totalXP == RewardRule.questXP)

        // A new day is a new completion.
        let tomorrow = progress.complete(quest.id, on: day.next, at: date, completionID: UUID(), transactionID: UUID())
        #expect((try? tomorrow.get()) != nil)
        #expect(progress.totalXP == RewardRule.questXP * 2)
    }

    @Test func rewardsAreTheSameForEveryCategory() throws {
        for category in GoalCategory.allCases {
            var progress = try started()
            let goal = try progress.addGoal(title: "x", category: category, at: date, makeID: UUID.init).get()
            let quest = try #require(progress.quests(of: goal.id).first)
            let reward = try progress.complete(quest.id, on: day, at: date, completionID: UUID(), transactionID: UUID())
                .get()
            #expect(reward.sparkleDelta == RewardRule.questSparkles && reward.xpDelta == RewardRule.questXP)
        }
    }

    @Test func archivedGoalsAndUnknownQuestsCannotBeCompleted() throws {
        var progress = try started()
        let goal = try progress.addGoal(title: "休む", category: .rest, at: date, makeID: UUID.init).get()
        let quest = try #require(progress.quests(of: goal.id).first)
        _ = progress.archiveGoal(goal.id)
        let archived = progress.complete(quest.id, on: day, at: date, completionID: UUID(), transactionID: UUID())
        #expect(archived == .failure(.goalArchived(goal.id)))
        let unknown = UUID()
        let missing = progress.complete(unknown, on: day, at: date, completionID: UUID(), transactionID: UUID())
        #expect(missing == .failure(.unknownQuest(unknown)))
        #expect(progress.totalXP == 0)
    }

    @Test func undoReversesOnlySameDayAndOnlyIfNotSpent() throws {
        var progress = try started(sparkles: 0)
        let goal = try progress.addGoal(title: "動く", category: .move, at: date, makeID: UUID.init).get()
        let quest = try #require(progress.quests(of: goal.id).first)
        let completionID = UUID()
        _ = try progress.complete(quest.id, on: day, at: date, completionID: completionID, transactionID: UUID()).get()

        let lateUndo = progress.undoCompletion(completionID, today: day.next, at: date, transactionID: UUID())
        #expect(lateUndo == .failure(.undoOnlySameDay))

        _ = try progress.purchase(.flower, at: date, transactionID: UUID()).get()  // spends the 5 earned
        let spentUndo = progress.undoCompletion(completionID, today: day, at: date, transactionID: UUID())
        #expect(spentUndo == .failure(.notEnoughSparkles(needed: 5, balance: 0)))
        #expect(progress.sparkles == 0)
    }

    @Test func undoThenRedoIsNotADoubleReward() throws {
        var progress = try started()
        let goal = try progress.addGoal(title: "作る", category: .create, at: date, makeID: UUID.init).get()
        let quest = try #require(progress.quests(of: goal.id).first)
        let completionID = UUID()
        _ = try progress.complete(quest.id, on: day, at: date, completionID: completionID, transactionID: UUID()).get()
        _ = try progress.undoCompletion(completionID, today: day, at: date, transactionID: UUID()).get()
        #expect(progress.totalXP == 0 && progress.sparkles == RewardRule.welcomeSparkles)
        #expect(!progress.isCompleted(quest.id, on: day))
        _ = try progress.complete(quest.id, on: day, at: date, completionID: UUID(), transactionID: UUID()).get()
        #expect(progress.totalXP == RewardRule.questXP)
    }

    @Test func purchasesNeedEnoughSparklesAndAddToStorage() throws {
        var progress = try started(sparkles: 25)
        let tooExpensive = progress.purchase(.house, at: date, transactionID: UUID())
        #expect(tooExpensive == .failure(.notEnoughSparkles(needed: 30, balance: 25)))
        _ = try progress.purchase(.pond, at: date, transactionID: UUID()).get()
        #expect(progress.sparkles == 5 && progress.owned[.pond] == 1)
        let world = try TestWorlds.grass()
        #expect(progress.available(.pond, in: world) == 1)
    }

    @Test func validationRejectsInconsistentSaves() throws {
        let completionID = UUID()
        let twice = [
            RewardTransaction(
                id: UUID(), reason: .questCompleted(completionID: completionID), xpDelta: 20, sparkleDelta: 5,
                ruleVersion: 1, date: date),
            RewardTransaction(
                id: UUID(), reason: .questCompleted(completionID: completionID), xpDelta: 20, sparkleDelta: 5,
                ruleVersion: 1, date: date),
        ]
        #expect(throws: ProgressError.alreadyRewarded(completionID)) { try PlayerProgress(ledger: twice) }
        let overspent = [
            RewardTransaction(
                id: UUID(), reason: .purchase(.house), xpDelta: 0, sparkleDelta: -30, ruleVersion: 1, date: date)
        ]
        #expect(throws: ProgressError.negativeBalance) { try PlayerProgress(ledger: overspent) }
        let orphan = QuestTemplate(id: UUID(), goalID: UUID(), title: "x", minutes: 5)
        #expect(throws: ProgressError.unknownGoal(orphan.goalID)) { try PlayerProgress(quests: [orphan]) }
    }

    @Test func levelsFollowXP() {
        #expect(RewardRule.level(forXP: 0) == 1)
        #expect(RewardRule.level(forXP: 99) == 1)
        #expect(RewardRule.level(forXP: 100) == 2)
        #expect(RewardRule.level(forXP: -5) == 1)
    }

    @Test func startingProgressOwnsThePlacedObjects() {
        let world = IslandFactory.makeWorld()
        let progress = PlayerProgress.starting(for: world, at: date, id: UUID())
        #expect(progress.owned.values.reduce(0, +) == world.objects.count)
        #expect(ObjectKind.allCases.allSatisfy { progress.available($0, in: world) == 0 })
        #expect(progress.sparkles == RewardRule.welcomeSparkles)
    }
}

@Suite("Today's quests")
struct DailyPlannerTests {
    let date = Date(timeIntervalSince1970: 1_800_000_000)
    let day = LocalDay(year: 2027, month: 1, day: 15)

    private func twoGoals() throws -> PlayerProgress {
        var progress = try PlayerProgress()
        _ = try progress.addGoal(title: "片付け", category: .tidy, at: date, makeID: UUID.init).get()
        _ = try progress.addGoal(title: "勉強", category: .study, at: date.addingTimeInterval(1), makeID: UUID.init).get()
        return progress
    }

    @Test func noGoalsMeansNoQuests() throws {
        #expect(DailyPlanner.suggestions(for: day, in: try PlayerProgress()).isEmpty)
    }

    @Test func alternatesBetweenGoalsAndIsStableWithinADay() throws {
        let progress = try twoGoals()
        let picked = DailyPlanner.suggestions(for: day, in: progress)
        #expect(picked.count == DailyPlanner.dailyCount)
        let goals = progress.activeGoals.map(\.id)
        #expect(picked.map(\.goalID) == [goals[0], goals[1], goals[0]])
        #expect(DailyPlanner.suggestions(for: day, in: progress) == picked)
    }

    @Test func completedAndSkippedQuestsAreReplaced() throws {
        var progress = try twoGoals()
        let first = try #require(DailyPlanner.suggestions(for: day, in: progress).first)
        _ = try progress.complete(first.id, on: day, at: date, completionID: UUID(), transactionID: UUID()).get()
        let second = try #require(DailyPlanner.suggestions(for: day, in: progress).first)
        progress.skip(second.id, on: day)
        let now = DailyPlanner.suggestions(for: day, in: progress)
        #expect(!now.contains { $0.id == first.id || $0.id == second.id })
        // Skips only last for the day.
        #expect(DailyPlanner.suggestions(for: day.next, in: progress).count == DailyPlanner.dailyCount)
    }
}

@Suite("Local day")
struct LocalDayTests {
    @Test func dependsOnTheCalendarTimeZone() throws {
        let instant = Date(timeIntervalSince1970: 1_800_000_000)  // 2027-01-15 08:00 UTC
        var tokyo = Calendar(identifier: .gregorian)
        tokyo.timeZone = try #require(TimeZone(identifier: "Asia/Tokyo"))
        var honolulu = Calendar(identifier: .gregorian)
        honolulu.timeZone = try #require(TimeZone(identifier: "Pacific/Honolulu"))
        #expect(LocalDay(date: instant, calendar: tokyo) == LocalDay(year: 2027, month: 1, day: 15))
        #expect(LocalDay(date: instant, calendar: honolulu) == LocalDay(year: 2027, month: 1, day: 14))
    }

    @Test func parsesTheStoredForm() {
        #expect(LocalDay(string: "2027-01-05") == LocalDay(year: 2027, month: 1, day: 5))
        #expect(LocalDay(year: 2027, month: 1, day: 5).description == "2027-01-05")
        #expect(LocalDay(string: "2027-13-01") == nil)
        #expect(LocalDay(string: "nope") == nil)
    }
}

extension LocalDay {
    /// Test helper: a later day (exact calendar arithmetic is not needed here).
    var next: LocalDay { LocalDay(year: year, month: month, day: day + 1) }
}
