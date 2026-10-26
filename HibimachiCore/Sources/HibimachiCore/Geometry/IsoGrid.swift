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

/// Isometric (2:1 diamond) projection between tile coordinates and scene coordinates (y up).
///
/// Tile (0, 0) is the front-most (bottom) tile; +x runs up-right and +y runs up-left on screen.
/// The land plane is lifted by `baseHeight` so cliffs and sea fit below the island inside `mapSize`.
public struct IsoGrid: Equatable, Sendable {
    public let tileWidth: Double
    public let tileHeight: Double
    public let columns: Int
    public let rows: Int
    public let baseHeight: Double

    public init(tileWidth: Double = 64, tileHeight: Double = 32, columns: Int, rows: Int, baseHeight: Double = 48) {
        precondition(tileWidth > 0 && tileHeight > 0, "tile size must be positive")
        self.tileWidth = tileWidth
        self.tileHeight = tileHeight
        self.columns = columns
        self.rows = rows
        self.baseHeight = baseHeight
    }

    private var halfWidth: Double { tileWidth / 2 }
    private var halfHeight: Double { tileHeight / 2 }

    public var mapSize: SceneSize {
        SceneSize(
            width: Double(columns + rows) * halfWidth,
            height: Double(columns + rows) * halfHeight + baseHeight
        )
    }

    /// Scene point of a continuous tile position (integer values are tile corners).
    public func point(x: Double, y: Double) -> ScenePoint {
        ScenePoint(x: (x - y + Double(rows)) * halfWidth, y: (x + y) * halfHeight + baseHeight)
    }

    /// Inverse of `point(x:y:)`.
    public func tilePosition(at point: ScenePoint) -> (x: Double, y: Double) {
        let u = point.x / halfWidth - Double(rows)
        let v = (point.y - baseHeight) / halfHeight
        return ((u + v) / 2, (v - u) / 2)
    }

    public func center(of tile: TileCoord) -> ScenePoint {
        point(x: Double(tile.x) + 0.5, y: Double(tile.y) + 0.5)
    }

    public func center(of footprint: Footprint, at origin: TileCoord) -> ScenePoint {
        point(
            x: Double(origin.x) + Double(footprint.width) / 2,
            y: Double(origin.y) + Double(footprint.height) / 2)
    }

    /// Front (bottom) vertex of a footprint: where object art is anchored.
    public func frontVertex(at origin: TileCoord) -> ScenePoint {
        point(x: Double(origin.x), y: Double(origin.y))
    }

    /// The tile whose diamond contains `point`, or `nil` outside the map (taps there are ignored, not clamped).
    public func tile(at point: ScenePoint) -> TileCoord? {
        let position = tilePosition(at: point)
        let tile = TileCoord(x: Int(position.x.rounded(.down)), y: Int(position.y.rounded(.down)))
        return (0..<columns).contains(tile.x) && (0..<rows).contains(tile.y) ? tile : nil
    }

    /// Origin that centers `footprint` under a drag point, so dragging a 2x2 object feels anchored to its middle.
    public func origin(for footprint: Footprint, centeredAt point: ScenePoint) -> TileCoord {
        let position = tilePosition(at: point)
        return TileCoord(
            x: Int((position.x - Double(footprint.width) / 2 + 0.5).rounded(.down)),
            y: Int((position.y - Double(footprint.height) / 2 + 0.5).rounded(.down))
        )
    }

    /// Painter's-order key: larger values are nearer the viewer and must be drawn on top.
    public func depth(of footprint: Footprint, at origin: TileCoord) -> Double {
        let far = Double(columns + rows)
        return far - (Double(origin.x) + Double(footprint.width) / 2 + Double(origin.y) + Double(footprint.height) / 2)
    }
}
