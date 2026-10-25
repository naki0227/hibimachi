import Foundation
import HibimachiCore

/// Stores the island as one JSON file, written atomically (temp file + rename), so a crash or a failed write
/// leaves the previous save intact. Unreadable files are renamed aside instead of being overwritten.
public struct JSONFileWorldRepository: WorldRepository {
    public typealias Writer = @Sendable (Data, URL) throws -> Void

    public static let fileName = "world.json"

    private let directory: URL
    private let writer: Writer
    private let now: @Sendable () -> Date

    public init(
        directory: URL,
        writer: @escaping Writer = { data, url in try data.write(to: url, options: .atomic) },
        now: @escaping @Sendable () -> Date = Date.init
    ) {
        self.directory = directory
        self.writer = writer
        self.now = now
    }

    public var fileURL: URL { directory.appendingPathComponent(Self.fileName) }

    public func load() -> WorldLoadOutcome {
        guard FileManager.default.fileExists(atPath: fileURL.path) else { return .notFound }
        do {
            let data = try Data(contentsOf: fileURL)
            let header = try JSONDecoder().decode(SchemaHeader.self, from: data)
            guard header.schemaVersion == WorldRecord.currentSchemaVersion else {
                // Migrations from older versions go here once v2 exists. Newer files are never overwritten.
                throw WorldRecordError.unsupportedSchemaVersion(header.schemaVersion)
            }
            return .loaded(try JSONDecoder().decode(WorldRecord.self, from: data).makeWorld())
        } catch {
            return .unreadable(reason: String(describing: error), backupFileName: quarantine())
        }
    }

    public func save(_ world: World) throws {
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        try writer(try encoder.encode(WorldRecord(world)), fileURL)
    }

    /// Moves the unreadable file to `world.unreadable-<timestamp>.json`. Returns `nil` if even that failed.
    private func quarantine() -> String? {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(identifier: "UTC")
        formatter.dateFormat = "yyyyMMdd-HHmmss"
        let stamp = formatter.string(from: now())
        // Never replace an earlier backup: add a counter when the same second is used twice.
        for attempt in 0..<100 {
            let name = attempt == 0 ? "world.unreadable-\(stamp).json" : "world.unreadable-\(stamp)-\(attempt).json"
            let target = directory.appendingPathComponent(name)
            guard !FileManager.default.fileExists(atPath: target.path) else { continue }
            do {
                try FileManager.default.moveItem(at: fileURL, to: target)
                return name
            } catch {
                return nil
            }
        }
        return nil
    }
}
