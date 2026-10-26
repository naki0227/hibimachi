import Foundation

@testable import HibimachiCore

/// Deterministic UUIDs: 00000000-0000-0000-0000-000000000001, ...002, ...
final class SequentialIDs: @unchecked Sendable {
    private var next = 0

    func make() -> UUID {
        next += 1
        return UUID(uuidString: String(format: "00000000-0000-0000-0000-%012d", next)) ?? UUID()
    }
}

enum TestWorlds {
    /// All-grass rectangle, optionally with a water column at `waterColumn`.
    static func grass(
        width: Int = 8,
        height: Int = 8,
        objects: [WorldObject] = [],
        creatureAt position: TileCoord = TileCoord(x: 0, y: 0),
        waterColumn: Int? = nil,
        pathRow: Int? = nil
    ) throws -> World {
        var terrain = [Terrain](repeating: .grass, count: width * height)
        for y in 0..<height {
            for x in 0..<width {
                if x == waterColumn { terrain[y * width + x] = .water }
                if y == pathRow { terrain[y * width + x] = .path }
            }
        }
        return try World(
            width: width,
            height: height,
            terrain: terrain,
            objects: objects,
            creature: Creature(id: UUID(), position: position)
        )
    }

    static func object(_ kind: ObjectKind, _ x: Int, _ y: Int, id: UUID = UUID()) -> WorldObject {
        WorldObject(id: id, kind: kind, origin: TileCoord(x: x, y: y))
    }
}

/// Runs the simulation until `stop` matches an event or `limit` ticks pass. Returns all events seen.
func simulate(
    _ world: inout World,
    seed: UInt64 = 42,
    limit: Int = 400,
    until stop: (WorldEvent) -> Bool = { _ in false }
) -> [WorldEvent] {
    var rng = SeededRandom(seed: seed)
    var all: [WorldEvent] = []
    for _ in 0..<limit {
        let events = CreatureBrain.step(world: &world, rng: &rng)
        all.append(contentsOf: events)
        if events.contains(where: stop) { break }
    }
    return all
}

/// A saved game around `world` with plenty of きらめき, so island tests are not limited by the economy.
func snapshot(_ world: World, sparkles: Int = 1_000) -> GameSnapshot {
    let gift = RewardTransaction(
        id: UUID(), reason: .welcome, xpDelta: 0, sparkleDelta: sparkles, ruleVersion: 1,
        date: Date(timeIntervalSince1970: 0))
    let progress = (try? PlayerProgress(ledger: [gift])) ?? PlayerProgress.starting(for: world, at: Date(), id: UUID())
    return GameSnapshot(world: world, progress: progress)
}
