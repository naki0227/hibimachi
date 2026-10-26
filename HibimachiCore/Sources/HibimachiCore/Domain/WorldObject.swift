import Foundation

public struct WorldObject: Identifiable, Hashable, Sendable {
    public let id: UUID
    public let kind: ObjectKind
    public var origin: TileCoord
    /// When the player placed it (v4). `nil` for objects the island started with or saved before v4.
    public let placedAt: Date?

    public init(id: UUID, kind: ObjectKind, origin: TileCoord, placedAt: Date? = nil) {
        self.id = id
        self.kind = kind
        self.origin = origin
        self.placedAt = placedAt
    }

    public var tiles: [TileCoord] { kind.footprint.tiles(at: origin) }

    /// Distance from `tile` to the closest tile of this object's footprint.
    public func distance(from tile: TileCoord) -> Int {
        tiles.map { $0.chebyshevDistance(to: tile) }.min() ?? Int.max
    }
}
