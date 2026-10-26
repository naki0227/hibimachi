import SpriteKit

/// Drawing code for each object (art pixels, origin bottom-left). A 1x1 footprint is the diamond
/// front (16,0) / right (32,8) / back (16,16) / left (0,8); things stand on its center (16,8).
/// Long by nature: each sprite is a short list of shapes, kept together so the art is easy to tweak.
@MainActor
enum ObjectSprites {
    private typealias P = IslandArt.Palette

    static func roundTree() -> PixelCanvas {
        let c = PixelCanvas(width: 32, height: 46)
        c.ellipse(P.shadow, 4, 4, 24, 9)
        c.rect(P.woodDark, 14, 8, 5, 12)
        c.rect(P.wood, 14, 8, 3, 12)
        c.ellipse(P.leafDark, 3, 15, 27, 24)
        c.ellipse(P.leaf, 3, 18, 24, 24)
        c.ellipse(P.leaf, 8, 25, 18, 19)
        c.ellipse(P.leafLight, 7, 30, 11, 9)
        c.ellipse(P.leafDark, 20, 17, 9, 10)
        for (x, y) in [(10, 36), (13, 39), (19, 37), (6, 27), (24, 30), (16, 33)] { c.pixel(P.leafLight, x, y) }
        for (x, y) in [(21, 22), (12, 21), (25, 25)] { c.pixel(P.leafDark, x, y) }
        return c
    }

    static func pineTree() -> PixelCanvas {
        let c = PixelCanvas(width: 28, height: 50)
        c.ellipse(P.shadow, 3, 4, 22, 8)
        c.rect(P.woodDark, 12, 8, 4, 8)
        let layers: [(base: Double, half: Double, height: Double)] = [
            (13, 12, 14), (22, 10, 13), (31, 7.5, 12), (39, 5, 10),
        ]
        for layer in layers {
            c.polygon(
                P.pineDark,
                [(14 - layer.half, layer.base), (14 + layer.half, layer.base), (14, layer.base + layer.height)])
            c.polygon(P.pine, [(14 - layer.half, layer.base), (14, layer.base), (14, layer.base + layer.height)])
        }
        for (x, y) in [(9, 16), (11, 25), (12, 34), (8, 15)] { c.pixel(P.leafLight, x, y) }
        return c
    }

    static func house(lit: Bool) -> PixelCanvas {
        let c = PixelCanvas(width: 64, height: 62)
        c.polygon(P.shadow, [(32, 0), (64, 16), (32, 32), (0, 16)])
        let front = (32.0, 4.0), right = (58.0, 17.0), left = (6.0, 17.0)
        let wall = 18.0
        c.polygon(P.wall, [left, front, (front.0, front.1 + wall), (left.0, left.1 + wall)])
        c.polygon(P.wallShade, [front, right, (right.0, right.1 + wall), (front.0, front.1 + wall)])
        let glass = lit ? IslandArt.Palette.windowLit : P.window
        // Two windows on the left face, a door and a window on the right face (faces slope 1:2).
        for start in [10.0, 21.0] {
            let y = 17 - (start - 6) / 2 + 6
            c.polygon(P.woodDark, [(start - 1, y - 1), (start + 6, y - 4.5), (start + 6, y + 3.5), (start - 1, y + 7)])
            c.polygon(glass, [(start, y), (start + 5, y - 2.5), (start + 5, y + 2.5), (start, y + 5)])
        }
        c.polygon(P.woodDark, [(37, 6.5), (44, 10), (44, 22), (37, 18.5)])
        c.polygon(P.wood, [(38, 7.5), (43, 10), (43, 21), (38, 18.5)])
        c.pixel(P.petalYellow, 42, 15)
        c.polygon(P.woodDark, [(47, 15), (54, 18.5), (54, 26.5), (47, 23)])
        c.polygon(glass, [(48, 16.5), (53, 19), (53, 25.5), (48, 23)])
        // Hip roof: two visible planes meeting at a ridge.
        let eaveL = (2.0, 34.0), eaveF = (32.0, 19.0), eaveR = (62.0, 34.0)
        let ridgeL = (22.0, 50.0), ridgeR = (42.0, 50.0)
        c.polygon(P.roof, [eaveL, eaveF, ridgeR, ridgeL])
        c.polygon(P.roofShade, [eaveF, eaveR, ridgeR])
        c.line(P.roofShade, from: (4, 34), to: (31, 20.5))
        c.rect(P.brick, 45, 46, 5, 12)
        c.rect(P.woodDark, 44, 57, 7, 2)
        c.rect(P.cream, 46, 60, 2, 2)
        return c
    }

    static func bench() -> PixelCanvas {
        let c = PixelCanvas(width: 32, height: 26)
        c.ellipse(P.shadow, 6, 4, 22, 8)
        for x in [8.0, 22.0] {
            c.rect(P.woodDark, Int(x), Int(5 + (x - 8) / 2), 1, 6)
        }
        c.polygon(P.woodLight, [(6, 10), (24, 19), (24, 21.5), (6, 12.5)])
        c.polygon(P.wood, [(6, 12.5), (24, 21.5), (24, 23), (6, 14)])
        c.polygon(P.woodLight, [(8, 15), (25, 23.5), (25, 25.5), (8, 17)])
        return c
    }

    static func flowerBush() -> PixelCanvas {
        let c = PixelCanvas(width: 32, height: 26)
        c.ellipse(P.shadow, 4, 3, 24, 9)
        c.ellipse(P.leafDark, 4, 6, 25, 15)
        c.ellipse(P.leaf, 4, 8, 22, 14)
        c.ellipse(P.leafLight, 8, 14, 9, 6)
        let petals = [P.petalPink, P.petalWhite, P.petalYellow, P.petalPurple, P.petalPink]
        let spots = [(8, 13), (13, 18), (19, 15), (23, 11), (15, 10), (10, 17), (20, 19), (26, 15), (6, 10)]
        for (index, spot) in spots.enumerated() {
            let color = petals[index % petals.count]
            c.rect(color, spot.0, spot.1, 2, 2)
            c.pixel(P.petalYellow, spot.0, spot.1)
        }
        return c
    }

    static func pond() -> PixelCanvas {
        let c = PixelCanvas(width: 64, height: 34)
        c.polygon(P.rockDark, [(32, 0), (64, 16), (32, 32), (0, 16)])
        c.polygon(P.rock, [(32, 2), (61, 16.5), (32, 31), (3, 16.5)])
        c.polygon(P.pond, [(32, 5), (55, 16.5), (32, 28), (9, 16.5)])
        c.polygon(P.pondDeep, [(32, 10), (45, 16.5), (32, 23), (19, 16.5)])
        c.line(P.cream, from: (22, 20), to: (28, 23))
        c.line(P.cream, from: (36, 11), to: (40, 13))
        c.ellipse(P.leaf, 40, 18, 7, 4)
        c.ellipse(P.leaf, 16, 12, 6, 3)
        c.rect(P.petalPink, 42, 20, 2, 2)
        for (x, y) in [(6, 16), (20, 8), (44, 8), (58, 16), (30, 30), (12, 22)] { c.rect(P.rockDark, x, y, 2, 1) }
        return c
    }

    static func lamp(lit: Bool) -> PixelCanvas {
        let c = PixelCanvas(width: 16, height: 48)
        c.ellipse(P.shadow, 2, 5, 12, 5)
        c.rect(P.iron, 7, 8, 2, 28)
        c.rect(P.iron, 5, 8, 6, 2)
        c.rect(P.iron, 4, 35, 8, 9)
        c.rect(lit ? P.windowLit : SKColor(hex: 0xF6E7B0), 5, 36, 6, 7)
        c.rect(P.iron, 3, 44, 10, 2)
        c.rect(P.iron, 6, 46, 4, 2)
        return c
    }

    /// The island's creature: a round white mochi with a sprout. 22x20 px, feet at (11, 3).
    static func creature(sleeping: Bool) -> PixelCanvas {
        let c = PixelCanvas(width: 22, height: 20)
        c.ellipse(P.shadow, 3, 1, 16, 5)
        let bodyHeight: Double = sleeping ? 10 : 12
        c.ellipse(SKColor(hex: 0xC9C6BE), 2, 3, 18, bodyHeight + 1)
        c.ellipse(P.cream, 3, 4, 16, bodyHeight)
        c.ellipse(SKColor(hex: 0xE6E2D8), 4, 4, 14, 4)
        let eyeY = sleeping ? 8 : 9
        if sleeping {
            c.rect(P.ink, 7, eyeY, 2, 1)
            c.rect(P.ink, 13, eyeY, 2, 1)
        } else {
            c.rect(P.ink, 7, eyeY, 1, 2)
            c.rect(P.ink, 14, eyeY, 1, 2)
        }
        c.rect(P.apricot, 5, 7, 2, 1)
        c.rect(P.apricot, 15, 7, 2, 1)
        let top = Int(4 + bodyHeight)
        c.rect(P.leafDark, 11, top, 1, 2)
        c.rect(P.leafLight, 8, top + 2, 3, 2)
        c.rect(P.leaf, 12, top + 2, 3, 2)
        return c
    }
}
