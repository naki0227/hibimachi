import Foundation
import HibimachiCore

/// On-disk representation. Kept separate from domain types so storage concerns never leak into rules.
/// v1 (2026-10-25): island only. v2 (2026-10-26): adds `progress` (goals, quests, rewards, owned buildings).
/// v3 (2026-10-26): adds `album` (optional memories; photos are separate files).
/// v4 (2026-10-26): adds `residents` (newcomers) and a `species` on every creature record.
/// v5 (2026-10-26): adds `friendship` on creature records.
/// v6 (2026-10-26): adds `growthStage`; the map is 20x20 (older 16x16 islands are moved to its middle on load).
/// v7 (2026-10-27): album entries keep an amount and a coach comment, and the quest in progress is saved.
struct WorldRecord: Codable, Equatable {
    static let currentSchemaVersion = 7
    static let supportedSchemaVersions = 1...7

    struct ObjectRecord: Codable, Equatable {
        var id: UUID
        var kind: String
        var x: Int
        var y: Int
        /// When it was placed (v4); absent for starting objects and older saves.
        var placedAt: Date?
    }

    struct CreatureRecord: Codable, Equatable {
        var id: UUID
        var x: Int
        var y: Int
        /// Absent before v4: the original mochi.
        var species: String?
        /// Absent before v5: no friendship yet.
        var friendship: FriendshipRecord?
    }

    struct FriendshipRecord: Codable, Equatable {
        var points: Int
        var petDay: String?
        var petsOnPetDay: Int
    }

    var schemaVersion: Int
    var width: Int
    var height: Int
    /// One character per tile, row-major from the bottom row (see `Terrain` raw values).
    var terrain: String
    var objects: [ObjectRecord]
    var creature: CreatureRecord
    /// Residents after the first one (v4). Absent before v4.
    var residents: [CreatureRecord]?
    var discoveries: [String]
    /// Absent before v6: not grown yet.
    var growthStage: Int?
    /// Absent in v1 files; migrated by `makeSnapshot`.
    var progress: ProgressRecord?
    /// Absent before v3; an empty album then.
    var album: AlbumRecord?
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
    case unknownSpecies(String)
    case badPetDay(String)

    var description: String {
        switch self {
        case .unsupportedSchemaVersion(let version): "unsupported schema version \(version)"
        case .unknownTerrain(let character): "unknown terrain '\(character)'"
        case .unknownObjectKind(let kind): "unknown object kind '\(kind)'"
        case .invalidWorld(let error): "invalid world: \(error)"
        case .unknownSpecies(let species): "unknown species '\(species)'"
        case .badPetDay(let day): "bad pet day '\(day)'"
        }
    }
}

extension WorldRecord {
    init(_ snapshot: GameSnapshot) {
        self.init(snapshot.world)
        progress = ProgressRecord(snapshot.progress)
        album = AlbumRecord(snapshot.album)
    }

    /// Builds the saved game. v1 files get fresh progress (owning what is placed, plus the welcome gift).
    func makeSnapshot(migrationDate: Date, makeID: () -> UUID) throws -> GameSnapshot {
        let world = try makeWorld()
        if let progress {
            let restored = try progress.makeProgress()
            return GameSnapshot(
                world: world, progress: restored, album: try album?.makeAlbum(progress: restored) ?? Album())
        }
        return GameSnapshot(
            world: world, progress: PlayerProgress.starting(for: world, at: migrationDate, id: makeID()))
    }

    init(_ world: World) {
        schemaVersion = Self.currentSchemaVersion
        width = world.width
        height = world.height
        terrain = String(world.terrain.map(\.rawValue))
        objects = world.objects.map {
            ObjectRecord(id: $0.id, kind: $0.kind.rawValue, x: $0.origin.x, y: $0.origin.y, placedAt: $0.placedAt)
        }
        creature = CreatureRecord(world.creature)
        residents = world.residents.dropFirst().map(CreatureRecord.init)
        // Sorted so identical worlds produce identical files.
        discoveries = world.discoveries.map(\.rawValue).sorted()
        growthStage = world.growthStage == 0 ? nil : world.growthStage
        progress = nil
        album = nil
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
            return WorldObject(
                id: record.id, kind: kind, origin: TileCoord(x: record.x, y: record.y), placedAt: record.placedAt)
        }
        // Unknown discovery IDs (e.g. from a removed reaction) are dropped rather than failing the whole save.
        let known = Set(discoveries.compactMap(ReactionKind.init(rawValue:)))
        let first = try creature.makeCreature()
        let others = try (residents ?? []).map { try $0.makeCreature() }
        do {
            let world = try World(
                width: width,
                height: height,
                terrain: tiles,
                objects: worldObjects,
                creature: first,
                otherResidents: others,
                discoveries: known,
                growthStage: growthStage ?? 0
            )
            // Islands saved before v6 lived on a 16x16 map; they move to the middle of the larger one.
            return schemaVersion < 6 ? world.padded(toSize: IslandGrowth.mapSize) : world
        } catch {
            throw WorldRecordError.invalidWorld(error)
        }
    }
}

extension WorldRecord.CreatureRecord {
    init(_ creature: Creature) {
        let friendship = creature.friendship
        self.init(
            id: creature.id, x: creature.position.x, y: creature.position.y, species: creature.species.rawValue,
            friendship: friendship == Friendship()
                ? nil
                : WorldRecord.FriendshipRecord(
                    points: friendship.points, petDay: friendship.petDay?.description,
                    petsOnPetDay: friendship.petsOnPetDay))
    }

    func makeCreature() throws -> Creature {
        guard let species = Species(rawValue: species ?? Species.mochi.rawValue) else {
            throw WorldRecordError.unknownSpecies(species ?? "")
        }
        var petDay: LocalDay?
        if let stored = friendship?.petDay {
            guard let day = LocalDay(string: stored) else { throw WorldRecordError.badPetDay(stored) }
            petDay = day
        }
        let bond = Friendship(
            points: friendship?.points ?? 0, petDay: petDay, petsOnPetDay: friendship?.petsOnPetDay ?? 0)
        return Creature(id: id, species: species, position: TileCoord(x: x, y: y), friendship: bond)
    }
}
