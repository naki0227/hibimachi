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

    struct EntryRecord: Codable, Equatable {
        var id: UUID
        var day: String
        var createdAt: Date
        var text: String?
        var photo: PhotoRecord?
        var completionID: UUID?
        /// Absent before the before/after comparison (2026-10-26).
        var beforeEntryID: UUID?
    }

    var entries: [EntryRecord]
}

enum AlbumRecordError: Error, Equatable, CustomStringConvertible {
    case badDay(String)
    case unsafeFileName(String)
    case invalidEntry(AlbumError)

    var description: String {
        switch self {
        case .badDay(let value): "bad album day '\(value)'"
        case .unsafeFileName(let name): "unsafe photo file name '\(name)'"
        case .invalidEntry(let error): "invalid album entry: \(error)"
        }
    }
}

extension AlbumRecord {
    init(_ album: Album) {
        entries = album.entries.map { entry in
            EntryRecord(
                id: entry.id, day: entry.day.description, createdAt: entry.createdAt, text: entry.text,
                photo: entry.photo.map {
                    PhotoRecord(id: $0.id, fileName: $0.fileName, bytes: $0.bytes, createdAt: $0.createdAt)
                },
                completionID: entry.completionID, beforeEntryID: entry.beforeEntryID)
        }
    }

    /// Rebuilds the album through the same validation as new entries, so a tampered file cannot inject an
    /// over-long text, a link to a missing completion or a path outside the media folder.
    func makeAlbum(progress: PlayerProgress) throws -> Album {
        var album = Album()
        for record in entries {
            guard let day = LocalDay(string: record.day) else { throw AlbumRecordError.badDay(record.day) }
            let photo = try record.photo.map { photo in
                guard MediaReference.isSafeFileName(photo.fileName), photo.bytes >= 0 else {
                    throw AlbumRecordError.unsafeFileName(photo.fileName)
                }
                return MediaReference(
                    id: photo.id, fileName: photo.fileName, bytes: photo.bytes, createdAt: photo.createdAt)
            }
            let result = album.add(
                text: record.text, photo: photo, completionID: record.completionID, progress: progress, day: day,
                at: record.createdAt, id: record.id, before: record.beforeEntryID)
            if case .failure(let error) = result { throw AlbumRecordError.invalidEntry(error) }
        }
        return album
    }
}
