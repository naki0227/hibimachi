import Foundation
import Testing

@testable import HibimachiCore

@Suite("Task sessions and records")
struct TaskSessionTests {
    let date = Date(timeIntervalSince1970: 1_800_000_000)

    @Test func styleComesFromTheTitleFirstThenTheCategory() {
        #expect(RecordStyle.style(forQuestTitled: "机の上を5分だけ片付ける", in: .other) == .beforeAfter)
        #expect(RecordStyle.style(forQuestTitled: "晩ご飯を作る", in: .tidy) == .result)
        #expect(RecordStyle.style(forQuestTitled: "腕立て伏せ", in: .other) == .amount)
        #expect(RecordStyle.style(forQuestTitled: "Read 2 pages", in: .other) == .amount)
        #expect(RecordStyle.style(forQuestTitled: "ゆっくりする", in: .rest) == .feeling)
        #expect(RecordStyle.style(forQuestTitled: "なにか", in: .move) == .amount)
        #expect(RecordStyle.amount.defaultUnit(forQuestTitled: "教科書を2ページ読む") == .pages)
        #expect(RecordStyle.amount.defaultUnit(forQuestTitled: "スクワット") == .times)
        #expect(RecordStyle.amount.defaultUnit(forQuestTitled: "ストレッチ") == .minutes)
    }

    @Test func everyStyleCanBeCompletedWithoutAPhoto() {
        for style in RecordStyle.allCases {
            let words = RecordCheck(
                style: style, hasBeforePhoto: false, hasAfterPhoto: false,
                amount: TaskAmount(value: 10, unit: .minutes), note: "やった")
            #expect(words.isComplete, "\(style)")
        }
        let onlyBefore = RecordCheck(
            style: .beforeAfter, hasBeforePhoto: true, hasAfterPhoto: false, amount: nil, note: " ")
        #expect(!onlyBefore.isComplete && !onlyBefore.isEmpty)
        let both = RecordCheck(style: .beforeAfter, hasBeforePhoto: true, hasAfterPhoto: true, amount: nil, note: nil)
        #expect(both.isComplete)
        #expect(TaskAmount(value: 0, unit: .times) == nil && TaskAmount(value: 1000, unit: .times) == nil)
    }

    @Test func theRuleCoachReactsToWhatWasRecorded() throws {
        let ten = try #require(TaskAmount(value: 10, unit: .pages))
        func check(_ style: RecordStyle, after: Bool = false, amount: TaskAmount? = nil, note: String? = nil)
            -> RecordCheck
        {
            RecordCheck(style: style, hasBeforePhoto: after, hasAfterPhoto: after, amount: amount, note: note)
        }
        #expect(CoachLine.line(for: check(.beforeAfter, after: true)) == .tidied)
        #expect(CoachLine.line(for: check(.result, note: "カレー")) == .made)
        #expect(CoachLine.line(for: check(.amount, amount: ten)) == .did(ten))
        #expect(CoachLine.line(for: check(.amount, note: "がんばった")) == .recorded)
        #expect(CoachLine.line(for: check(.feeling, note: "すっきり")) == .rested)
        #expect(CoachLine.line(for: check(.result)) == .finished, "nothing recorded is still a finish")
    }

    @MainActor
    private func store() throws -> (GameStore, FakeRepository, FakeMediaStore, QuestTemplate) {
        let repository = FakeRepository(.loaded(snapshot(try TestWorlds.grass())))
        let media = FakeMediaStore()
        let store = GameStore(repository: repository, seed: 1, now: { date }, media: media)
        #expect(store.addGoal(title: "部屋", category: .tidy))
        let quest = try #require(store.progress.quests.first)
        return (store, repository, media, quest)
    }

    @MainActor
    @Test func beforeAndAfterBecomeAPairAndEarnTheBonus() throws {
        let (store, repository, media, quest) = try store()
        #expect(store.recordStyle(of: quest) == .beforeAfter)
        #expect(store.startTask(quest.id))
        #expect(!store.startTask(quest.id), "one at a time")
        #expect(store.attachSessionPhoto(Data([1]), to: .before))
        #expect(store.attachSessionPhoto(Data([2]), to: .before), "retaking replaces")
        #expect(media.files.count == 1)
        #expect(repository.saved.last?.album.session?.beforePhoto != nil, "kept across relaunches")

        let sparkles = store.progress.sparkles
        let finished = try #require(store.finishTask(afterJPEG: Data([3])))
        #expect(finished.check.isComplete)
        #expect(finished.bonus?.sparkleDelta == RewardRule.recordBonusSparkles)
        #expect(store.progress.sparkles == sparkles + RewardRule.questSparkles + RewardRule.recordBonusSparkles)
        #expect(store.activeSession == nil)
        let afterID = try #require(finished.entryID)
        let after = try #require(store.album.entry(afterID))
        let beforeID = try #require(after.beforeEntryID)
        let before = try #require(store.album.entry(beforeID))
        #expect(before.photo != nil && after.photo != nil)
        #expect(before.completionID == finished.completionID && after.completionID == finished.completionID)
        #expect(media.files.count == 2)

        // Undoing the quest takes the bonus back too.
        #expect(store.undoLastCompletion())
        #expect(store.progress.sparkles == sparkles)
    }

    @MainActor
    @Test func anAmountCompletesExerciseAndNothingRecordedStillCounts() throws {
        let repository = FakeRepository(.loaded(snapshot(try TestWorlds.grass())))
        let store = GameStore(repository: repository, seed: 1, now: { date }, media: FakeMediaStore())
        #expect(store.addGoal(title: "からだ", category: .move))
        let quests = store.progress.quests
        #expect(store.startTask(quests[0].id))
        let counted = try #require(store.finishTask(amount: TaskAmount(value: 20, unit: .times)))
        #expect(counted.bonus != nil)
        let countedID = try #require(counted.entryID)
        #expect(store.album.entry(countedID)?.amount?.value == 20)

        #expect(store.startTask(quests[1].id))
        let plain = try #require(store.finishTask())
        #expect(plain.bonus == nil && plain.entryID == nil && plain.check.isEmpty)
        #expect(store.progress.isCompleted(quests[1].id, on: store.today), "finishing always counts")
        #expect(!store.startTask(quests[1].id), "already done today")
    }

    @MainActor
    @Test func cancellingDeletesTheSessionsPhotosAndLongNotesAreRefusedFirst() throws {
        let (store, _, media, quest) = try store()
        #expect(store.startTask(quest.id))
        #expect(store.attachSessionPhoto(Data([1]), to: .during))
        store.cancelTask()
        #expect(store.activeSession == nil && media.files.isEmpty)
        #expect(!store.progress.isCompleted(quest.id, on: store.today))

        #expect(store.startTask(quest.id))
        let tooLong = String(repeating: "あ", count: Album.textLimit + 1)
        #expect(store.finishTask(afterJPEG: Data([2]), note: tooLong) == nil)
        #expect(store.lastAlbumError == .textTooLong(limit: Album.textLimit))
        #expect(media.files.isEmpty, "no photo saved for a refused finish")
        #expect(store.activeSession != nil, "the player can fix the note and finish")
    }

    @MainActor
    @Test func theCoachsCommentIsTrimmedAndKept() throws {
        let (store, repository, _, quest) = try store()
        #expect(store.startTask(quest.id))
        let finished = try #require(store.finishTask(note: "机の上"))
        let entryID = try #require(finished.entryID)
        store.setCoachComment("  " + String(repeating: "よ", count: 200) + " ", on: entryID)
        #expect(store.album.entry(entryID)?.coachComment?.count == Album.commentLimit)
        #expect(repository.saved.last?.album.entry(entryID)?.coachComment != nil)
    }
}
