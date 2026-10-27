import Foundation
import HibimachiCore

/// On-disk form of the album (added in schema v3). Photos are referenced by file name only.
struct AlbumRecord: Codable, Equatable {
    struct PhotoRecord: Codable, Equatable {
        var id: UUID
        var fileName: String
        var bytes: Int
        var createdAt: Date
    }

    struct AmountRecord: Codable, Equatable {
        var value: Int
        var unit: String
    }

    struct EntryRecord: Codable, Equatable {
        var id: UUID
        var day: String
        var createdAt: Date
        var text: String?
        var photo: PhotoRecord?
        var completionID: UUID?
        /// Absent before the before/after comparison (2026-10-26).
        var beforeEntryID: UUID?
        /// Absent before task records (v7, 2026-10-27).
        var amount: AmountRecord?
        var coachComment: String?
    }

    /// The quest in progress (v7).
    struct SessionRecord: Codable, Equatable {
        var questID: UUID
        var startedAt: Date
        var beforePhoto: PhotoRecord?
        var duringPhoto: PhotoRecord?
    }

    var entries: [EntryRecord]
    var session: SessionRecord?
}

enum AlbumRecordError: Error, Equatable, CustomStringConvertible {
    case badDay(String)
    case unsafeFileName(String)
    case invalidEntry(AlbumError)
    case badAmount(Int, String)

    var description: String {
        switch self {
        case .badDay(let value): "bad album day '\(value)'"
        case .unsafeFileName(let name): "unsafe photo file name '\(name)'"
        case .invalidEntry(let error): "invalid album entry: \(error)"
        case .badAmount(let value, let unit): "bad amount \(value) '\(unit)'"
        }
    }
}

extension AlbumRecord {
    init(_ album: Album) {
        entries = album.entries.map { entry in
            EntryRecord(
                id: entry.id, day: entry.day.description, createdAt: entry.createdAt, text: entry.text,
                photo: entry.photo.map(PhotoRecord.init), completionID: entry.completionID,
                beforeEntryID: entry.beforeEntryID,
                amount: entry.amount.map { AmountRecord(value: $0.value, unit: $0.unit.rawValue) },
                coachComment: entry.coachComment)
        }
        session = album.session.map {
            SessionRecord(
                questID: $0.questID, startedAt: $0.startedAt, beforePhoto: $0.beforePhoto.map(PhotoRecord.init),
                duringPhoto: $0.duringPhoto.map(PhotoRecord.init))
        }
    }

    /// Rebuilds the album through the same validation as new entries, so a tampered file cannot inject an
    /// over-long text, a link to a missing completion or a path outside the media folder.
    func makeAlbum(progress: PlayerProgress) throws -> Album {
        var album = Album()
        for record in entries {
            guard let day = LocalDay(string: record.day) else { throw AlbumRecordError.badDay(record.day) }
            let amount = try record.amount.map { amount in
                guard let unit = AmountUnit(rawValue: amount.unit),
                    let value = TaskAmount(value: amount.value, unit: unit)
                else { throw AlbumRecordError.badAmount(amount.value, amount.unit) }
                return value
            }
            let result = album.add(
                text: record.text, photo: try record.photo?.makeReference(), completionID: record.completionID,
                progress: progress, day: day, at: record.createdAt, id: record.id, before: record.beforeEntryID,
                amount: amount, coachComment: record.coachComment)
            if case .failure(let error) = result { throw AlbumRecordError.invalidEntry(error) }
        }
        // A session for a quest that no longer exists is dropped rather than making the save unreadable.
        if let session, progress.quests.contains(where: { $0.id == session.questID }) {
            let running = TaskSession(
                questID: session.questID, startedAt: session.startedAt,
                beforePhoto: try session.beforePhoto?.makeReference(),
                duringPhoto: try session.duringPhoto?.makeReference())
            album = Album(entries: album.entries, session: running)
        }
        return album
    }
}

extension AlbumRecord.PhotoRecord {
    init(_ reference: MediaReference) {
        self.init(
            id: reference.id, fileName: reference.fileName, bytes: reference.bytes, createdAt: reference.createdAt)
    }

    func makeReference() throws -> MediaReference {
        guard MediaReference.isSafeFileName(fileName), bytes >= 0 else {
            throw AlbumRecordError.unsafeFileName(fileName)
        }
        return MediaReference(id: id, fileName: fileName, bytes: bytes, createdAt: createdAt)
    }
}
