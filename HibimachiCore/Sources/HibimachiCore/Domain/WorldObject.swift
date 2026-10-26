import Foundation

public struct WorldObject: Identifiable, Hashable, Sendable {
    public let id: UUID
    public let kind: ObjectKind
    public var origin: TileCoord

    public init(id: UUID, kind: ObjectKind, origin: TileCoord) {
        self.id = id
        self.kind = kind
        self.origin = origin
    }

    public var tiles: [TileCoord] { kind.footprint.tiles(at: origin) }

    /// Distance from `tile` to the closest tile of this object's footprint.
    public func distance(from tile: TileCoord) -> Int {
        tiles.map { $0.chebyshevDistance(to: tile) }.min() ?? Int.max
    }
}
