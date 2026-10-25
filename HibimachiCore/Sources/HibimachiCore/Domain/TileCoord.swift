/// A logical tile position. `y` grows upwards to match SpriteKit's coordinate space.
public struct TileCoord: Hashable, Sendable, CustomStringConvertible {
    public var x: Int
    public var y: Int

    public init(x: Int, y: Int) {
        self.x = x
        self.y = y
    }

    public func offset(dx: Int, dy: Int) -> TileCoord {
        TileCoord(x: x + dx, y: y + dy)
    }

    /// Orthogonal neighbours in a fixed order, so path finding stays deterministic.
    public var neighbors: [TileCoord] {
        [offset(dx: 0, dy: 1), offset(dx: 1, dy: 0), offset(dx: 0, dy: -1), offset(dx: -1, dy: 0)]
    }

    /// King-move distance: "within N tiles" in any direction including diagonals.
    public func chebyshevDistance(to other: TileCoord) -> Int {
        max(abs(x - other.x), abs(y - other.y))
    }

    public var description: String { "(\(x), \(y))" }
}

/// Size of an object in tiles. Objects are axis-aligned rectangles anchored at their bottom-left tile.
public struct Footprint: Hashable, Sendable {
    public let width: Int
    public let height: Int

    public init(width: Int, height: Int) {
        self.width = width
        self.height = height
    }

    public func tiles(at origin: TileCoord) -> [TileCoord] {
        var result: [TileCoord] = []
        result.reserveCapacity(width * height)
        for dy in 0..<height {
            for dx in 0..<width {
                result.append(origin.offset(dx: dx, dy: dy))
            }
        }
        return result
    }
}
