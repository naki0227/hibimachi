import Foundation

/// The starting island. Layout values are provisional (16x16, docs/GAME-DESIGN.md) and tuned by playtests.
public enum IslandFactory {
    /// Top row first for readability; converted so that y = 0 is the bottom row.
    static let layout: [String] = [
        "wwwwwwwwwwwwwwww",
        "wwwggggggggggwww",
        "wwggggggpggggggw",
        "wgggggggpggggggw",
        "wgggggggpggggggw",
        "wgggggggpgggggww",
        "wgggggggpggggggw",
        "wgppppppppppppgw",
        "wgggggggpggggggw",
        "wwggggggpggggggw",
        "wgggggggpggggggw",
        "wgggggggpggggggw",
        "wgggggggpgggggww",
        "wwgggggggggggggw",
        "wwwgggggggggggww",
        "wwwwwwwwwwwwwwww",
    ]

    public static var size: Int { layout.count }

    public static func makeTerrain() -> [Terrain] {
        layout.reversed().flatMap { row in row.map { Terrain(rawValue: $0) ?? .water } }
    }

    /// Builds the default island. `makeID` is injectable so tests get stable IDs.
    public static func makeWorld(makeID: () -> UUID = UUID.init) -> World {
        let objects: [(ObjectKind, TileCoord)] = [
            (.house, TileCoord(x: 3, y: 11)),
            (.roundTree, TileCoord(x: 11, y: 12)),
            (.pineTree, TileCoord(x: 13, y: 11)),
            (.bench, TileCoord(x: 10, y: 9)),
            (.flower, TileCoord(x: 4, y: 4)),
            (.pond, TileCoord(x: 11, y: 3)),
        ]
        let creature = Creature(id: makeID(), position: TileCoord(x: 8, y: 8))
        do {
            return try World(
                width: size,
                height: size,
                terrain: makeTerrain(),
                objects: objects.map { WorldObject(id: makeID(), kind: $0.0, origin: $0.1) },
                creature: creature
            )
        } catch {
            // The layout is a compile-time constant covered by tests; reaching this is a programming error.
            preconditionFailure("Default island is invalid: \(error)")
        }
    }
}
