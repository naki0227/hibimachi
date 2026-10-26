import Foundation
import Testing

@testable import HibimachiCore

/// In-memory photo store that can be told to fail.
final class FakeMediaStore: MediaStore, @unchecked Sendable {
    struct Failed: Error {}
    var failSaves = false
    private(set) var files: [String: Data] = [:]

    func savePhoto(_ data: Data, id: UUID, at date: Date) throws -> MediaReference {
        if failSaves { throw Failed() }
        let name = "\(id.uuidString).jpg"
        files[name] = data
        return MediaReference(id: id, fileName: name, bytes: data.count, createdAt: date)
    }

    func delete(_ reference: MediaReference) throws { files[reference.fileName] = nil }
    func url(for reference: MediaReference) -> URL { URL(fileURLWithPath: "/tmp/\(reference.fileName)") }
}

@Suite("Growth album")
struct AlbumTests {
    let date = Date(timeIntervalSince1970: 1_800_000_000)
    let day = LocalDay(year: 2027, month: 1, day: 15)

    private func progressWithCompletion() throws -> (PlayerProgress, UUID) {
        let gift = RewardTransaction(
            id: UUID(), reason: .welcome, xpDelta: 0, sparkleDelta: 30, ruleVersion: 1, date: date)
        var progress = try PlayerProgress(ledger: [gift])
        let goal = try progress.addGoal(title: "学ぶ", category: .study, at: date, makeID: UUID.init).get()
        let quest = try #require(progress.quests(of: goal.id).first)
        let completionID = UUID()
        _ = progress.complete(quest.id, on: day, at: date, completionID: completionID, transactionID: UUID())
        return (progress, completionID)
    }

    @Test func entriesNeedTextOrPhotoAndStayShort() throws {
        let (progress, completionID) = try progressWithCompletion()
        var album = Album()
        let empty = album.add(
            text: "  \n ", photo: nil, completionID: nil, progress: progress, day: day, at: date, id: UUID())
        #expect(empty == .failure(.empty))
        let long = album.add(
            text: String(repeating: "あ", count: Album.textLimit + 1), photo: nil, completionID: nil,
            progress: progress, day: day, at: date, id: UUID())
        #expect(long == .failure(.textTooLong(limit: Album.textLimit)))
        let unknown = UUID()
        let badLink = album.add(
            text: "ok", photo: nil, completionID: unknown, progress: progress, day: day, at: date, id: UUID())
        #expect(badLink == .failure(.unknownCompletion(unknown)))
        let entry = try album.add(
            text: " 単語を覚えた ", photo: nil, completionID: completionID, progress: progress, day: day, at: date,
            id: UUID()
        ).get()
        #expect(entry.text == "単語を覚えた")
        #expect(album.entries.count == 1)
        #expect(album.remove(entry.id) == entry)
        #expect(album.remove(entry.id) == nil)
    }

    @Test func historyGroupsQuestsPurchasesAndMemoriesByDayNewestFirst() throws {
        var (progress, completionID) = try progressWithCompletion()
        let nextDay = date.addingTimeInterval(86_400)
        _ = try progress.purchase(.bench, at: nextDay, transactionID: UUID()).get()
        var album = Album()
        _ = album.add(
            text: "がんばった", photo: nil, completionID: completionID, progress: progress, day: day, at: date, id: UUID())
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "UTC") ?? .gmt
        let days = AlbumDay.history(progress: progress, album: album, calendar: calendar)
        #expect(days.count == 2)
        #expect(days[0].purchases == [.bench])
        #expect(days[1].day == day)
        #expect(days[1].quests.map(\.completionID) == [completionID])
        #expect(days[1].sparklesEarned == RewardRule.questSparkles)
        #expect(days[1].memories.map(\.text) == ["がんばった"])
    }

    @Test func unsafeFileNamesAreRecognised() {
        #expect(MediaReference.isSafeFileName("abc.jpg"))
        #expect(!MediaReference.isSafeFileName("../world.json"))
        #expect(!MediaReference.isSafeFileName("a/b.jpg"))
        #expect(!MediaReference.isSafeFileName(".hidden"))
        #expect(!MediaReference.isSafeFileName(""))
    }
}

@MainActor
@Suite("GameStore album use cases")
struct GameStoreAlbumTests {
    let date = Date(timeIntervalSince1970: 1_800_000_000)

    private func store(media: FakeMediaStore?) throws -> (GameStore, FakeRepository) {
        let repository = FakeRepository(.loaded(snapshot(try TestWorlds.grass(), sparkles: 30)))
        let store = GameStore(repository: repository, seed: 1, now: { date }, media: media)
        return (store, repository)
    }

    @Test func memoryWithPhotoIsSavedAndDeletedWithItsFile() throws {
        let media = FakeMediaStore()
        let (store, repository) = try store(media: media)
        #expect(store.addMemory(text: "海がきれい", photoJPEG: Data([1, 2, 3])))
        let entry = try #require(store.album.entries.first)
        #expect(entry.photo?.bytes == 3)
        #expect(media.files.count == 1)
        #expect(repository.saved.last?.album == store.album)
        #expect(store.album.photoBytes == 3)

        #expect(store.deleteMemory(entry.id))
        #expect(store.album.entries.isEmpty)
        #expect(media.files.isEmpty)
        #expect(!store.deleteMemory(entry.id))
        #expect(store.lastAlbumError == .notFound(entry.id))
    }

    @Test func refusedEntryLeavesNoOrphanPhoto() throws {
        let media = FakeMediaStore()
        let (store, _) = try store(media: media)
        let tooLong = String(repeating: "a", count: Album.textLimit + 1)
        #expect(!store.addMemory(text: tooLong, photoJPEG: Data([1])))
        #expect(media.files.isEmpty)
        #expect(store.lastAlbumError == .textTooLong(limit: Album.textLimit))
    }

    @Test func photoProblemsAreReportedAndNothingIsSaved() throws {
        let (noMedia, _) = try store(media: nil)
        #expect(!noMedia.addMemory(text: "", photoJPEG: Data([1])))
        #expect(noMedia.lastAlbumError == .photoUnavailable)
        #expect(noMedia.addMemory(text: "ことばだけ"))  // text-only works without a media store

        let failing = FakeMediaStore()
        failing.failSaves = true
        let (store, _) = try store(media: failing)
        #expect(!store.addMemory(text: "x", photoJPEG: Data([1])))
        #expect(store.album.entries.isEmpty)
    }

    @Test func resettingTheIslandKeepsTheAlbum() throws {
        let (store, _) = try store(media: nil)
        store.addMemory(text: "思い出")
        store.resetIsland()
        #expect(store.album.entries.count == 1)
    }
}
