import Foundation
import Testing

@testable import HibimachiCore

@MainActor
@Suite("Quest board and completing quests outside the app")
struct QuestBoardTests {
    let date = Date(timeIntervalSince1970: 1_800_000_000)
    let calendar: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Asia/Tokyo") ?? .gmt
        return calendar
    }()

    private var day: LocalDay { LocalDay(date: date, calendar: calendar) }

    private func savedGame(goal: Bool = true) throws -> (FakeRepository, PlayerProgress) {
        var game = snapshot(try TestWorlds.grass(), sparkles: 30)
        if goal {
            _ = try game.progress.addGoal(title: "部屋", category: .tidy, at: date, makeID: UUID.init).get()
        }
        return (FakeRepository(.loaded(game)), game.progress)
    }

    @Test func boardListsOpenQuestsThenDoneOnes() throws {
        var (_, progress) = try savedGame()
        let first = QuestBoard.make(progress: progress, day: day)
        #expect(first.hasGoals)
        #expect(first.items.count == DailyPlanner.dailyCount)
        #expect(first.remaining == DailyPlanner.dailyCount)
        #expect(first.items.allSatisfy { $0.goalTitle == "部屋" && !$0.isDone })

        let done = first.items[0]
        _ = progress.complete(done.id, on: day, at: date, completionID: UUID(), transactionID: UUID())
        let after = QuestBoard.make(progress: progress, day: day)
        #expect(
            after.items.last
                == QuestBoard.Item(
                    id: done.id, title: done.title, goalTitle: "部屋", minutes: done.minutes, isDone: true))
        #expect(!after.items.dropLast().contains { $0.id == done.id })
        #expect(after.sparkles == 30 + RewardRule.questSparkles)
    }

    @Test func boardWithoutGoalsInvitesIntoTheApp() throws {
        let (_, progress) = try savedGame(goal: false)
        let board = QuestBoard.make(progress: progress, day: day)
        #expect(!board.hasGoals)
        #expect(board.items.isEmpty)
    }

    @Test func quickCompletionRewardsOnceAndSaves() throws {
        let (repository, progress) = try savedGame()
        let quest = try #require(QuestBoard.make(progress: progress, day: day).items.first)
        let reward = QuickQuestCompletion.complete(quest.id, repository: repository, at: date, calendar: calendar)
        #expect((try? reward.get())?.sparkleDelta == RewardRule.questSparkles)
        let saved = try #require(repository.saved.last)
        #expect(saved.progress.sparkles == 30 + RewardRule.questSparkles)

        // A second tap on the same day (e.g. a stale widget) is refused and changes nothing.
        repository.loadOutcome = .loaded(saved)
        let again = QuickQuestCompletion.complete(quest.id, repository: repository, at: date, calendar: calendar)
        #expect(again == .failure(.progress(.alreadyCompletedToday(quest.id))))
        #expect(repository.saved.count == 1)
    }

    @Test func quickCompletionNeverCreatesOrReplacesASave() {
        let missing = FakeRepository(.notFound)
        #expect(QuickQuestCompletion.complete(UUID(), repository: missing, at: date) == .failure(.noSave))
        let broken = FakeRepository(.unreadable(reason: "bad", backupFileName: nil))
        #expect(QuickQuestCompletion.complete(UUID(), repository: broken, at: date) == .failure(.noSave))
        #expect(missing.saved.isEmpty && broken.saved.isEmpty)
    }

    @Test func appPicksUpWidgetCompletionsWhenItComesBack() throws {
        let (repository, progress) = try savedGame()
        let store = GameStore(repository: repository, seed: 1, now: { date }, calendar: calendar)
        let quest = try #require(store.todaysQuests.first)
        #expect(!store.reloadProgressFromStorage())  // nothing changed on disk

        QuickQuestCompletion.complete(quest.id, repository: repository, at: date, calendar: calendar)
        repository.loadOutcome = .loaded(try #require(repository.saved.last))
        #expect(store.reloadProgressFromStorage())
        #expect(store.progress.sparkles == progress.sparkles + RewardRule.questSparkles)
        #expect(store.completedToday.map(\.questID) == [quest.id])
    }

    @Test func reloadKeepsUnsavedProgressWhileSavesFail() throws {
        let (repository, _) = try savedGame()
        let store = GameStore(repository: repository, seed: 1, now: { date }, calendar: calendar)
        repository.failSaves = true
        let quest = try #require(store.todaysQuests.first)
        store.completeQuest(quest.id)
        #expect(store.saveErrorMessage != nil)
        #expect(!store.reloadProgressFromStorage())
        #expect(store.completedToday.count == 1)
    }
}
