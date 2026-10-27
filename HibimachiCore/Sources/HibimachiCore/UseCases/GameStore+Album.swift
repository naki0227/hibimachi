import Foundation

/// P2 use cases: keep an optional memory (text and/or one photo) for today, read the history, delete.
extension GameStore {
    public var albumDays: [AlbumDay] { AlbumDay.history(progress: progress, album: album, calendar: calendar) }

    /// Saves the photo first, then the entry; if the entry is refused the new photo file is removed again.
    /// A failed save does not undo the entry: it stays in memory and the save-error banner offers a retry.
    @discardableResult
    public func addMemory(
        text: String, photoJPEG: Data? = nil, completionID: UUID? = nil, before: UUID? = nil
    ) -> Bool {
        let date = nowForProgress
        var photo: MediaReference?
        if let photoJPEG {
            guard let media else {
                setAlbumError(.photoUnavailable)
                return false
            }
            do {
                photo = try media.savePhoto(photoJPEG, id: makeIDForProgress(), at: date)
            } catch {
                setAlbumError(.photoSaveFailed(String(describing: error)))
                return false
            }
        }
        var result: Result<MemoryEntry, AlbumError> = .failure(.empty)
        let entryID = makeIDForProgress()
        updateAlbum { album in
            result = album.add(
                text: text, photo: photo, completionID: completionID, progress: progress, day: today, at: date,
                id: entryID, before: before)
        }
        switch result {
        case .success:
            setAlbumError(nil)
            return true
        case .failure(let error):
            if let photo { try? media?.delete(photo) }
            setAlbumError(error)
            return false
        }
    }

    /// Removes the entry from the save, then its photo file. The file is kept when the save failed: the file on
    /// disk may still point at it after a relaunch, and a leftover file is only wasted space.
    @discardableResult
    public func deleteMemory(_ id: UUID) -> Bool {
        var removed: MemoryEntry?
        updateAlbum { removed = $0.remove(id) }
        guard let removed else {
            setAlbumError(.notFound(id))
            return false
        }
        if let photo = removed.photo, saveErrorMessage == nil { try? media?.delete(photo) }
        setAlbumError(nil)
        return true
    }

    public func photoURL(for entry: MemoryEntry) -> URL? {
        entry.photo.flatMap { media?.url(for: $0) }
    }

    public func photoURL(for reference: MediaReference) -> URL? { media?.url(for: reference) }
}
