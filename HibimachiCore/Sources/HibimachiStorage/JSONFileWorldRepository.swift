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
            return .loaded(try read())
        } catch {
            return .unreadable(reason: String(describing: error), backupFileName: quarantine())
        }
    }

    public func peek() -> GameSnapshot? {
        guard FileManager.default.fileExists(atPath: fileURL.path) else { return nil }
        return try? read()
    }

    private func read() throws -> GameSnapshot {
        let data = try Data(contentsOf: fileURL)
        let header = try JSONDecoder().decode(SchemaHeader.self, from: data)
        guard WorldRecord.supportedSchemaVersions.contains(header.schemaVersion) else {
            // Newer files are never overwritten: they are moved aside like corrupt ones.
            throw WorldRecordError.unsupportedSchemaVersion(header.schemaVersion)
        }
        let record = try Self.decoder.decode(WorldRecord.self, from: data)
        return try record.makeSnapshot(migrationDate: now(), makeID: UUID.init)
    }

    public func save(_ snapshot: GameSnapshot) throws {
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        try writer(try encoder.encode(WorldRecord(snapshot)), fileURL)
    }

    private static var decoder: JSONDecoder {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return decoder
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
