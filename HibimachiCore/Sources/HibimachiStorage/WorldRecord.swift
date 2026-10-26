import Foundation
import HibimachiCore

/// On-disk representation. Kept separate from domain types so storage concerns never leak into rules.
/// v1 (2026-10-25): island only. v2 (2026-10-26): adds `progress` (goals, quests, rewards, owned buildings).
struct WorldRecord: Codable, Equatable {
    static let currentSchemaVersion = 2
    static let supportedSchemaVersions = 1...2

    struct ObjectRecord: Codable, Equatable {
        var id: UUID
        var kind: String
        var x: Int
        var y: Int
    }

    struct CreatureRecord: Codable, Equatable {
        var id: UUID
        var x: Int
        var y: Int
    }

    var schemaVersion: Int
    var width: Int
    var height: Int
    /// One character per tile, row-major from the bottom row (see `Terrain` raw values).
    var terrain: String
    var objects: [ObjectRecord]
    var creature: CreatureRecord
    var discoveries: [String]
    /// Absent in v1 files; migrated by `makeSnapshot`.
    var progress: ProgressRecord?
}

/// Only the version field, decoded first so newer files are recognised before full decoding fails.
struct SchemaHeader: Decodable {
    var schemaVersion: Int
}

enum WorldRecordError: Error, Equatable, CustomStringConvertible {
    case unsupportedSchemaVersion(Int)
    case unknownTerrain(Character)
    case unknownObjectKind(String)
    case invalidWorld(WorldValidationError)

    var description: String {
        switch self {
        case .unsupportedSchemaVersion(let version): "unsupported schema version \(version)"
        case .unknownTerrain(let character): "unknown terrain '\(character)'"
        case .unknownObjectKind(let kind): "unknown object kind '\(kind)'"
        case .invalidWorld(let error): "invalid world: \(error)"
        }
    }
}

extension WorldRecord {
    init(_ snapshot: GameSnapshot) {
        self.init(snapshot.world)
        progress = ProgressRecord(snapshot.progress)
    }

    /// Builds the saved game. v1 files get fresh progress (owning what is placed, plus the welcome gift).
    func makeSnapshot(migrationDate: Date, makeID: () -> UUID) throws -> GameSnapshot {
        let world = try makeWorld()
        if let progress {
            return GameSnapshot(world: world, progress: try progress.makeProgress())
        }
        return GameSnapshot(
            world: world, progress: PlayerProgress.starting(for: world, at: migrationDate, id: makeID()))
    }

    init(_ world: World) {
        schemaVersion = Self.currentSchemaVersion
        width = world.width
        height = world.height
        terrain = String(world.terrain.map(\.rawValue))
        objects = world.objects.map { ObjectRecord(id: $0.id, kind: $0.kind.rawValue, x: $0.origin.x, y: $0.origin.y) }
        creature = CreatureRecord(id: world.creature.id, x: world.creature.position.x, y: world.creature.position.y)
        // Sorted so identical worlds produce identical files.
        discoveries = world.discoveries.map(\.rawValue).sorted()
        progress = nil
    }

    func makeWorld() throws -> World {
        guard Self.supportedSchemaVersions.contains(schemaVersion) else {
            throw WorldRecordError.unsupportedSchemaVersion(schemaVersion)
        }
        let tiles = try terrain.map { character in
            guard let tile = Terrain(rawValue: character) else { throw WorldRecordError.unknownTerrain(character) }
            return tile
        }
        let worldObjects = try objects.map { record in
            guard let kind = ObjectKind(rawValue: record.kind) else {
                throw WorldRecordError.unknownObjectKind(record.kind)
            }
            return WorldObject(id: record.id, kind: kind, origin: TileCoord(x: record.x, y: record.y))
        }
        // Unknown discovery IDs (e.g. from a removed reaction) are dropped rather than failing the whole save.
        let known = Set(discoveries.compactMap(ReactionKind.init(rawValue:)))
        do {
            return try World(
                width: width,
                height: height,
                terrain: tiles,
                objects: worldObjects,
                creature: Creature(id: creature.id, position: TileCoord(x: creature.x, y: creature.y)),
                discoveries: known
            )
        } catch {
            throw WorldRecordError.invalidWorld(error)
        }
    }
}
