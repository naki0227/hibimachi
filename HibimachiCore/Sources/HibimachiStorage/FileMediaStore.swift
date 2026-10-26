import Foundation
import HibimachiCore

/// Photos as `<id>.jpg` files in one folder, written atomically. The app strips metadata and downsizes
/// before calling `savePhoto`; this type only stores bytes.
public struct FileMediaStore: MediaStore {
    private let directory: URL

    public init(directory: URL) {
        self.directory = directory
    }

    public func savePhoto(_ data: Data, id: UUID, at date: Date) throws -> MediaReference {
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let name = "\(id.uuidString.lowercased()).jpg"
        try data.write(to: directory.appendingPathComponent(name), options: .atomic)
        return MediaReference(id: id, fileName: name, bytes: data.count, createdAt: date)
    }

    public func delete(_ reference: MediaReference) throws {
        let url = url(for: reference)
        guard FileManager.default.fileExists(atPath: url.path) else { return }
        try FileManager.default.removeItem(at: url)
    }

    public func url(for reference: MediaReference) -> URL {
        // References are validated on load; this guard keeps a bad name from escaping the folder anyway.
        let name = MediaReference.isSafeFileName(reference.fileName) ? reference.fileName : "invalid"
        return directory.appendingPathComponent(name)
    }
}
