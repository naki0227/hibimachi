import Foundation

/// A photo kept by the app. Only a file name relative to the app's media folder is stored, never an absolute
/// path, so moving the container or restoring a backup keeps working.
public struct MediaReference: Equatable, Sendable {
    public let id: UUID
    public let fileName: String
    public let bytes: Int
    public let createdAt: Date

    public init(id: UUID, fileName: String, bytes: Int, createdAt: Date) {
        self.id = id
        self.fileName = fileName
        self.bytes = bytes
        self.createdAt = createdAt
    }

    /// Plain file names only: a tampered save must not point outside the media folder.
    public static func isSafeFileName(_ name: String) -> Bool {
        !name.isEmpty && name.count <= 64 && !name.contains("/") && !name.contains("\\") && !name.hasPrefix(".")
    }
}

/// One optional memory: a short text, a photo, or both, on a day (and optionally tied to a quest completion).
public struct MemoryEntry: Identifiable, Equatable, Sendable {
    public let id: UUID
    public let day: LocalDay
    public let createdAt: Date
    public let text: String?
    public let photo: MediaReference?
    public let completionID: UUID?
    /// An earlier entry whose photo is the "before" of this one's ("after"). Cleared if that entry is deleted.
    public internal(set) var beforeEntryID: UUID?

    public init(
        id: UUID, day: LocalDay, createdAt: Date, text: String?, photo: MediaReference?, completionID: UUID?,
        beforeEntryID: UUID? = nil
    ) {
        self.id = id
        self.day = day
        self.createdAt = createdAt
        self.text = text
        self.photo = photo
        self.completionID = completionID
        self.beforeEntryID = beforeEntryID
    }
}

public enum AlbumError: Error, Equatable, Sendable {
    case empty
    case textTooLong(limit: Int)
    case unknownCompletion(UUID)
    case notFound(UUID)
    case photoUnavailable
    case photoSaveFailed(String)
    /// A before/after pair needs a photo on both sides.
    case comparisonNeedsPhotos
}

/// The growth album (P2). Recording is optional and earns nothing: the island never depends on photos or text.
public struct Album: Equatable, Sendable {
    public static let textLimit = 200

    public private(set) var entries: [MemoryEntry]

    public init(entries: [MemoryEntry] = []) {
        self.entries = entries
    }

    public var photoBytes: Int { entries.compactMap(\.photo).reduce(0) { $0 + $1.bytes } }
    public var photoCount: Int { entries.filter { $0.photo != nil }.count }

    /// Earlier entries with a photo, newest first: the choices for a "before".
    public var photoEntries: [MemoryEntry] { entries.filter { $0.photo != nil }.reversed() }

    public func entry(_ id: UUID) -> MemoryEntry? { entries.first { $0.id == id } }

    /// Validates and adds an entry. `completionID`, when given, must be one of the player's completions.
    /// `before`, when given, must be an existing entry with a photo, and this entry needs a photo too.
    public mutating func add(
        text: String?, photo: MediaReference?, completionID: UUID?, progress: PlayerProgress, day: LocalDay,
        at date: Date, id: UUID, before: UUID? = nil
    ) -> Result<MemoryEntry, AlbumError> {
        let trimmed = text?.trimmingCharacters(in: .whitespacesAndNewlines)
        let body = (trimmed?.isEmpty ?? true) ? nil : trimmed
        guard body != nil || photo != nil else { return .failure(.empty) }
        if let body, body.count > Self.textLimit { return .failure(.textTooLong(limit: Self.textLimit)) }
        if let completionID, !progress.completions.contains(where: { $0.id == completionID }) {
            return .failure(.unknownCompletion(completionID))
        }
        if let before {
            guard let earlier = entry(before) else { return .failure(.notFound(before)) }
            guard earlier.photo != nil, photo != nil else { return .failure(.comparisonNeedsPhotos) }
        }
        let entry = MemoryEntry(
            id: id, day: day, createdAt: date, text: body, photo: photo, completionID: completionID,
            beforeEntryID: before)
        entries.append(entry)
        return .success(entry)
    }

    @discardableResult
    public mutating func remove(_ id: UUID) -> MemoryEntry? {
        guard let index = entries.firstIndex(where: { $0.id == id }) else { return nil }
        // Afters that compared with this entry keep their own photo and lose only the link.
        for other in entries.indices where entries[other].beforeEntryID == id { entries[other].beforeEntryID = nil }
        return entries.remove(at: index)
    }
}

/// Where photo bytes live (implemented in HibimachiStorage). The album only keeps references.
public protocol MediaStore: Sendable {
    func savePhoto(_ data: Data, id: UUID, at date: Date) throws -> MediaReference
    func delete(_ reference: MediaReference) throws
    func url(for reference: MediaReference) -> URL
}
