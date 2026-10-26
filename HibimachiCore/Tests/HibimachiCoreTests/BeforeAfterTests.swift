import Foundation
import Testing

@testable import HibimachiCore

@Suite("Before / after")
struct BeforeAfterTests {
    let date = Date(timeIntervalSince1970: 1_800_000_000)
    let day = LocalDay(year: 2027, month: 1, day: 15)

    private func photo(_ name: String) -> MediaReference {
        MediaReference(id: UUID(), fileName: name, bytes: 10, createdAt: date)
    }

    @Test func anAfterPointsAtAnEarlierPhotoAndBothNeedPhotos() throws {
        var album = Album()
        let progress = try PlayerProgress()
        let before = try album.add(
            text: "散らかった机", photo: photo("a.jpg"), completionID: nil, progress: progress, day: day, at: date,
            id: UUID()
        ).get()
        let words = try album.add(
            text: "ことばだけ", photo: nil, completionID: nil, progress: progress, day: day, at: date, id: UUID()
        ).get()
        let after = try album.add(
            text: "片付いた！", photo: photo("b.jpg"), completionID: nil, progress: progress, day: day.next,
            at: date, id: UUID(), before: before.id
        ).get()
        #expect(after.beforeEntryID == before.id)
        #expect(album.photoEntries.map(\.id) == [after.id, before.id], "newest first, photos only")

        let noPhoto = album.add(
            text: "x", photo: nil, completionID: nil, progress: progress, day: day, at: date, id: UUID(),
            before: before.id)
        #expect(noPhoto == .failure(.comparisonNeedsPhotos))
        let beforeWithoutPhoto = album.add(
            text: "x", photo: photo("c.jpg"), completionID: nil, progress: progress, day: day, at: date, id: UUID(),
            before: words.id)
        #expect(beforeWithoutPhoto == .failure(.comparisonNeedsPhotos))
        let missing = UUID()
        let unknown = album.add(
            text: "x", photo: photo("d.jpg"), completionID: nil, progress: progress, day: day, at: date, id: UUID(),
            before: missing)
        #expect(unknown == .failure(.notFound(missing)))
    }

    @Test func deletingTheBeforeKeepsTheAfterWithoutTheLink() throws {
        var album = Album()
        let progress = try PlayerProgress()
        let before = try album.add(
            text: nil, photo: photo("a.jpg"), completionID: nil, progress: progress, day: day, at: date, id: UUID()
        ).get()
        let after = try album.add(
            text: nil, photo: photo("b.jpg"), completionID: nil, progress: progress, day: day, at: date, id: UUID(),
            before: before.id
        ).get()
        album.remove(before.id)
        #expect(album.entry(after.id)?.beforeEntryID == nil)
        #expect(album.entry(after.id)?.photo != nil)
    }

    @MainActor
    @Test func theStoreKeepsAComparisonAndSavesIt() throws {
        let repository = FakeRepository(.loaded(snapshot(try TestWorlds.grass())))
        let store = GameStore(repository: repository, seed: 1, now: { date }, media: FakeMediaStore())
        #expect(store.addMemory(text: "before", photoJPEG: Data([1])))
        let before = try #require(store.album.entries.first)
        #expect(store.addMemory(text: "after", photoJPEG: Data([2]), before: before.id))
        #expect(repository.saved.last?.album.entries.last?.beforeEntryID == before.id)
        #expect(!store.addMemory(text: "only words", before: before.id))
        #expect(store.lastAlbumError == .comparisonNeedsPhotos)
    }
}
