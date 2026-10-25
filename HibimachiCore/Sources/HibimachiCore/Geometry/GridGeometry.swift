/// A 2D point/size in scene units, kept framework-free (no CoreGraphics) so the math is testable anywhere.
public struct ScenePoint: Equatable, Sendable {
    public var x: Double
    public var y: Double

    public init(x: Double, y: Double) {
        self.x = x
        self.y = y
    }
}

public struct SceneSize: Equatable, Sendable {
    public var width: Double
    public var height: Double

    public init(width: Double, height: Double) {
        self.width = width
        self.height = height
    }
}

/// Converts between tile coordinates and scene coordinates. Tile (0, 0) covers [0, tileSize) on both axes.
public struct GridGeometry: Equatable, Sendable {
    public let tileSize: Double
    public let columns: Int
    public let rows: Int

    public init(tileSize: Double, columns: Int, rows: Int) {
        precondition(tileSize > 0, "tileSize must be positive")
        self.tileSize = tileSize
        self.columns = columns
        self.rows = rows
    }

    public var mapSize: SceneSize {
        SceneSize(width: Double(columns) * tileSize, height: Double(rows) * tileSize)
    }

    public func center(of tile: TileCoord) -> ScenePoint {
        ScenePoint(x: (Double(tile.x) + 0.5) * tileSize, y: (Double(tile.y) + 0.5) * tileSize)
    }

    /// Center of a multi-tile footprint anchored at `origin`.
    public func center(of footprint: Footprint, at origin: TileCoord) -> ScenePoint {
        ScenePoint(
            x: (Double(origin.x) + Double(footprint.width) / 2) * tileSize,
            y: (Double(origin.y) + Double(footprint.height) / 2) * tileSize
        )
    }

    /// The tile under `point`, or `nil` outside the map (taps there are ignored, not clamped).
    public func tile(at point: ScenePoint) -> TileCoord? {
        guard point.x >= 0, point.y >= 0 else { return nil }
        let tile = TileCoord(x: Int(point.x / tileSize), y: Int(point.y / tileSize))
        return (0..<columns).contains(tile.x) && (0..<rows).contains(tile.y) ? tile : nil
    }

    /// Origin that centers `footprint` under a drag point, so dragging a 2x2 object feels anchored to its middle.
    public func origin(for footprint: Footprint, centeredAt point: ScenePoint) -> TileCoord {
        TileCoord(
            x: Int((point.x / tileSize - Double(footprint.width) / 2 + 0.5).rounded(.down)),
            y: Int((point.y / tileSize - Double(footprint.height) / 2 + 0.5).rounded(.down))
        )
    }
}
