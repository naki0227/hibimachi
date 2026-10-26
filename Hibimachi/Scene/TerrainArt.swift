import HibimachiCore
import SpriteKit

/// Renders the whole island (grass, paths, cliffs and surrounding water) into one pixel-art texture.
/// One texture instead of 256 nodes keeps the scene cheap; it is re-rendered only when terrain changes.
@MainActor
enum TerrainArt {
    private typealias P = IslandArt.Palette
    /// Land plane offset inside the texture, in art pixels (= IsoGrid.baseHeight / pixel).
    static let basePixels = 24.0
    static let cliffPixels = 10.0

    static func texture(for world: World) -> SKTexture {
        let width = (world.width + world.height) * 16
        let height = (world.width + world.height) * 8 + Int(basePixels)
        let canvas = PixelCanvas(width: width, height: height)
        // Painter's order: farthest (largest x + y) first.
        for sum in stride(from: world.width + world.height - 2, through: 0, by: -1) {
            for x in 0..<world.width {
                let y = sum - x
                guard (0..<world.height).contains(y) else { continue }
                let tile = TileCoord(x: x, y: y)
                switch world.terrain(at: tile) {
                case .water, nil: drawWater(tile, world: world, rows: world.height, on: canvas)
                case .grass, .path: drawLand(tile, world: world, rows: world.height, on: canvas)
                }
            }
        }
        return canvas.makeTexture()
    }

    private static func corner(_ x: Int, _ y: Int, rows: Int, lift: Double = 0) -> (Double, Double) {
        (Double(x - y + rows) * 16, Double(x + y) * 8 + basePixels + lift)
    }

    private static func isLand(_ tile: TileCoord, in world: World) -> Bool {
        world.terrain(at: tile)?.isLand ?? false
    }

    private static func drawWater(_ tile: TileCoord, world: World, rows: Int, on c: PixelCanvas) {
        let drop = -cliffPixels
        let (bx, by) = corner(tile.x, tile.y, rows: rows, lift: drop)
        let nearLand = (-1...1).contains { dx in
            (-1...1).contains { dy in isLand(tile.offset(dx: dx, dy: dy), in: world) }
        }
        c.polygon(nearLand ? P.shallow : P.sea, [(bx, by), (bx + 16, by + 8), (bx, by + 16), (bx - 16, by + 8)])
        let noise = PixelNoise.value(tile.x, tile.y, 7)
        if nearLand {
            c.rect(P.shallowLight, Int(bx) - 4 + noise % 6, Int(by) + 6 + noise % 4, 3, 1)
        } else if noise < 450 {
            c.rect(P.seaWave, Int(bx) - 6 + noise % 10, Int(by) + 5 + noise % 6, 4, 1)
        }
    }

    private static func drawLand(_ tile: TileCoord, world: World, rows: Int, on c: PixelCanvas) {
        let b = corner(tile.x, tile.y, rows: rows)
        let r = corner(tile.x + 1, tile.y, rows: rows)
        let t = corner(tile.x + 1, tile.y + 1, rows: rows)
        let l = corner(tile.x, tile.y + 1, rows: rows)
        let drop = cliffPixels
        let rightOpen = !isLand(tile.offset(dx: 0, dy: -1), in: world)
        let leftOpen = !isLand(tile.offset(dx: -1, dy: 0), in: world)
        if rightOpen {
            c.polygon(P.cliffDark, [b, r, (r.0, r.1 - drop), (b.0, b.1 - drop)])
            c.line(P.cliffShade, from: (b.0, b.1 - drop / 2), to: (r.0, r.1 - drop / 2))
            c.line(P.foam, from: (b.0, b.1 - drop), to: (r.0 - 1, r.1 - drop))
        }
        if leftOpen {
            c.polygon(P.cliffLight, [l, b, (b.0, b.1 - drop), (l.0, l.1 - drop)])
            c.line(P.cliffDark, from: (l.0, l.1 - drop / 2 - 1), to: (b.0, b.1 - drop / 2 - 1))
            c.line(P.foam, from: (l.0 + 1, l.1 - drop), to: (b.0, b.1 - drop))
        }
        let terrain = world.terrain(at: tile) ?? .grass
        let checker = (tile.x + tile.y).isMultiple(of: 2)
        let base: SKColor =
            terrain == .path ? (checker ? P.path : P.pathAlt) : (checker ? P.grass : P.grassAlt)
        c.polygon(base, [b, r, t, l])
        decorate(tile, terrain: terrain, center: (b.0, b.1 + 8), on: c)
        if rightOpen { c.line(P.grassDark, from: (b.0, b.1), to: (r.0 - 1, r.1)) }
        if leftOpen { c.line(P.grassDark, from: (l.0 + 1, l.1), to: (b.0, b.1)) }
    }

    /// Speckles, tiny wildflowers and cobbles, chosen by hash so the island looks hand-made but stable.
    private static func decorate(_ tile: TileCoord, terrain: Terrain, center: (Double, Double), on c: PixelCanvas) {
        for dy in -6...6 {
            for dx in -13...13 where Double(abs(dx)) / 14 + Double(abs(dy)) / 7 <= 1 {
                let x = Int(center.0) + dx
                let y = Int(center.1) + dy
                let noise = PixelNoise.value(x, y, terrain == .path ? 3 : 1)
                switch terrain {
                case .path:
                    if noise < 70 { c.rect(P.stone, x, y, 2, 1) } else if noise < 110 { c.pixel(P.stoneLight, x, y) }
                case .grass, .water:
                    if noise < 45 {
                        c.pixel(P.grassDark, x, y)
                    } else if noise < 75 {
                        c.pixel(P.grassLight, x, y)
                    } else if noise < 79 {
                        let petals = [P.petalWhite, P.petalPink, P.petalYellow]
                        c.pixel(petals[noise % petals.count], x, y)
                    }
                }
            }
        }
    }

    /// A small distant islet for the backdrop (purely decorative).
    static func isletTexture(variant: Int) -> SKTexture {
        let c = PixelCanvas(width: 40, height: 30)
        c.ellipse(P.shallow, 0, 0, 40, 12)
        c.ellipse(P.cliffDark, 5, 3, 30, 14)
        c.ellipse(P.cliffLight, 5, 5, 26, 12)
        c.ellipse(P.grass, 6, 9, 28, 11)
        c.ellipse(P.grassLight, 10, 14, 10, 4)
        if variant.isMultiple(of: 2) {
            c.polygon(P.pineDark, [(24, 14), (32, 14), (28, 27)])
            c.polygon(P.pine, [(24, 14), (28, 14), (28, 27)])
        } else {
            c.ellipse(P.leaf, 12, 14, 12, 10)
            c.ellipse(P.leafLight, 14, 19, 5, 3)
        }
        c.line(P.foam, from: (4, 4), to: (12, 2))
        return c.makeTexture()
    }
}
