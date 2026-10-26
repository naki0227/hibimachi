import SpriteKit

/// v1.0 objects (same conventions as `ObjectSprites`: art pixels, origin bottom-left; a 1x1 footprint's front
/// vertex is (16, 0), a 2x2 one's is (32, 0)). Long by nature: each sprite is a short list of shapes.
@MainActor
extension ObjectSprites {
    private typealias V = IslandArt.Palette

    static func sakuraTree() -> PixelCanvas {
        let c = PixelCanvas(width: 32, height: 46)
        c.ellipse(V.shadow, 4, 4, 24, 9)
        c.rect(V.woodDark, 14, 8, 5, 12)
        c.rect(V.wood, 14, 8, 3, 12)
        c.ellipse(V.sakuraDark, 3, 15, 27, 24)
        c.ellipse(V.petalPink, 3, 18, 24, 24)
        c.ellipse(V.sakuraLight, 8, 25, 18, 19)
        c.ellipse(V.petalWhite, 8, 31, 9, 7)
        for (x, y) in [(10, 36), (19, 37), (6, 27), (24, 30), (16, 33), (21, 22), (12, 21)] {
            c.pixel(V.petalWhite, x, y)
        }
        for (x, y) in [(7, 4), (25, 6), (19, 3)] { c.rect(V.petalPink, x, y, 2, 1) }  // fallen petals
        return c
    }

    static func bush() -> PixelCanvas {
        let c = PixelCanvas(width: 32, height: 22)
        c.ellipse(V.shadow, 6, 3, 20, 8)
        c.ellipse(V.leafDark, 6, 5, 21, 14)
        c.ellipse(V.leaf, 6, 7, 18, 13)
        c.ellipse(V.leafLight, 10, 13, 8, 5)
        for (x, y) in [(13, 10), (20, 14), (9, 12)] { c.pixel(V.leafDark, x, y) }
        return c
    }

    static func rock() -> PixelCanvas {
        let c = PixelCanvas(width: 32, height: 20)
        c.ellipse(V.shadow, 5, 3, 22, 8)
        c.ellipse(V.rockDark, 6, 4, 20, 13)
        c.ellipse(V.rock, 6, 6, 17, 11)
        c.ellipse(SKColor(hex: 0xD6D0C4), 10, 11, 7, 4)
        c.ellipse(V.rockDark, 20, 4, 8, 6)
        c.ellipse(V.rock, 20, 5, 6, 5)
        c.rect(V.leaf, 7, 5, 2, 2)
        return c
    }

    static func fence() -> PixelCanvas {
        let c = PixelCanvas(width: 32, height: 22)
        // Runs along the tile's back-left edge, rising 1 px for every 2 px to the right.
        for (x, y) in [(3.0, 7.0), (15.0, 13.0), (27.0, 19.0)] {
            c.rect(V.woodDark, Int(x), Int(y) - 4, 3, 13)
            c.rect(V.woodLight, Int(x), Int(y) - 4, 2, 13)
        }
        for offset in [1.0, 6.0] {
            c.polygon(V.wood, [(2, 4 + offset), (30, 18 + offset), (30, 20 + offset), (2, 6 + offset)])
        }
        return c
    }

    static func mailbox() -> PixelCanvas {
        let c = PixelCanvas(width: 16, height: 32)
        c.ellipse(V.shadow, 2, 4, 12, 5)
        c.rect(V.woodDark, 7, 6, 2, 14)
        c.rect(V.roofShade, 2, 19, 12, 8)
        c.rect(V.roof, 2, 21, 10, 7)
        c.ellipse(V.roof, 2, 24, 10, 6)
        c.rect(V.cream, 4, 23, 5, 1)
        c.rect(V.petalYellow, 12, 24, 1, 6)
        c.rect(V.petalYellow, 12, 29, 3, 2)
        return c
    }

    static func picnicMat() -> PixelCanvas {
        let c = PixelCanvas(width: 32, height: 20)
        c.polygon(V.roofShade, [(16, 1), (30, 8), (16, 15), (2, 8)])
        c.polygon(V.cream, [(16, 2), (28, 8), (16, 14), (4, 8)])
        for step in 0..<3 {
            let t = Double(step) * 4
            c.polygon(
                V.roof, [(7 + t, 6.5 + t / 2), (9 + t, 5.5 + t / 2), (21 + t, 11.5 + t / 2), (19 + t, 12.5 + t / 2)])
        }
        c.rect(V.woodDark, 18, 9, 7, 5)
        c.rect(V.woodLight, 18, 12, 7, 2)
        c.rect(V.roof, 20, 14, 2, 2)
        c.rect(V.leaf, 22, 14, 2, 1)
        return c
    }

    static func birdhouse() -> PixelCanvas {
        let c = PixelCanvas(width: 16, height: 42)
        c.ellipse(V.shadow, 3, 4, 10, 5)
        c.rect(V.woodDark, 7, 6, 2, 22)
        c.rect(V.woodLight, 3, 27, 10, 9)
        c.rect(V.wood, 9, 27, 4, 9)
        c.polygon(V.roofShade, [(1, 35), (8, 41), (15, 35)])
        c.polygon(V.roof, [(2, 35), (8, 40), (8, 35)])
        c.ellipse(V.ink, 6, 30, 4, 4)
        c.rect(V.woodDark, 7, 28, 2, 1)
        return c
    }

    static func swing() -> PixelCanvas {
        let c = PixelCanvas(width: 32, height: 42)
        c.ellipse(V.shadow, 6, 3, 20, 8)
        for (x, y) in [(5.0, 9.0), (25.0, 19.0)] {
            c.rect(V.woodDark, Int(x) - 1, Int(y) - 4, 3, 26)
            c.rect(V.woodLight, Int(x) - 1, Int(y) - 4, 2, 26)
        }
        c.polygon(V.wood, [(3, 30), (28, 41), (28, 43), (3, 32)])
        c.line(V.iron, from: (12, 33), to: (12, 15))
        c.line(V.iron, from: (19, 36), to: (19, 18))
        c.polygon(V.roof, [(10, 13), (21, 18.5), (21, 20.5), (10, 15)])
        return c
    }

    static func campfire(lit: Bool) -> PixelCanvas {
        let c = PixelCanvas(width: 32, height: 30)
        c.ellipse(V.shadow, 5, 3, 22, 9)
        for (x, y) in [(6, 7), (11, 4), (18, 4), (23, 7), (20, 10), (9, 10)] {
            c.ellipse(V.rockDark, Double(x), Double(y), 5, 4)
            c.ellipse(V.rock, Double(x), Double(y) + 1, 4, 3)
        }
        c.polygon(V.woodDark, [(10, 7), (12, 6), (22, 11), (20, 12)])
        c.polygon(V.wood, [(20, 6), (22, 7), (12, 12), (10, 11)])
        let outer = lit ? SKColor(hex: 0xF5873A) : SKColor(hex: 0xE9773A)
        c.polygon(outer, [(10, 10), (16, 26), (22, 10)])
        c.polygon(V.petalYellow, [(13, 10), (16, 20), (19, 10)])
        c.polygon(V.cream, [(15, 10), (16, 14), (17, 10)])
        return c
    }

    static func well() -> PixelCanvas {
        let c = PixelCanvas(width: 32, height: 44)
        c.ellipse(V.shadow, 4, 3, 24, 9)
        c.rect(V.rockDark, 6, 6, 20, 12)
        c.rect(V.rock, 6, 7, 18, 11)
        for (x, y) in [(8, 9), (14, 12), (20, 9), (11, 15), (19, 15)] { c.rect(V.rockDark, x, y, 3, 1) }
        c.ellipse(V.rockDark, 5, 14, 22, 9)
        c.ellipse(V.pondDeep, 8, 16, 16, 5)
        c.rect(V.woodDark, 6, 18, 2, 18)
        c.rect(V.woodDark, 24, 18, 2, 18)
        c.polygon(V.roofShade, [(2, 34), (16, 43), (30, 34)])
        c.polygon(V.roof, [(3, 34), (16, 42), (16, 34)])
        c.rect(V.woodLight, 13, 21, 6, 4)
        c.line(V.iron, from: (16, 25), to: (16, 34))
        return c
    }

    static func garden() -> PixelCanvas {
        let c = PixelCanvas(width: 64, height: 38)
        c.polygon(V.woodDark, [(32, 0), (64, 16), (32, 32), (0, 16)])
        c.polygon(SKColor(hex: 0x8C5E3F), [(32, 2), (61, 16.5), (32, 31), (3, 16.5)])
        for row in 0..<4 {
            let t = Double(row) * 6
            c.polygon(
                SKColor(hex: 0x6E4630),
                [(10 + t, 13 + t / 2), (12 + t, 12 + t / 2), (40 + t, 26 + t / 2), (38 + t, 27 + t / 2)])
            for step in 0..<5 {
                let x = 14 + t + Double(step) * 6, y = 16 + t / 2 + Double(step) * 3
                c.rect(V.leafDark, Int(x), Int(y), 3, 3)
                c.rect(V.leafLight, Int(x), Int(y) + 2, 2, 2)
                if (row + step).isMultiple(of: 3) { c.rect(V.roof, Int(x) + 2, Int(y), 2, 2) }
            }
        }
        c.rect(V.woodLight, 50, 22, 2, 12)
        c.rect(V.cream, 47, 31, 8, 5)
        return c
    }

    static func fountain() -> PixelCanvas {
        let c = PixelCanvas(width: 64, height: 54)
        c.polygon(V.shadow, [(32, 0), (64, 16), (32, 32), (0, 16)])
        c.polygon(V.rockDark, [(32, 2), (60, 16), (32, 30), (4, 16)])
        c.polygon(V.rock, [(32, 2), (60, 16), (60, 22), (32, 36), (4, 22), (4, 16)])
        c.polygon(SKColor(hex: 0xD6D0C4), [(32, 9), (56, 21), (32, 33), (8, 21)])
        c.polygon(V.pond, [(32, 12), (51, 21.5), (32, 31), (13, 21.5)])
        c.rect(V.rockDark, 29, 21, 7, 14)
        c.rect(V.rock, 29, 21, 5, 14)
        c.ellipse(V.rock, 24, 33, 17, 6)
        c.ellipse(V.pond, 26, 34, 13, 4)
        for (dx, h) in [(-7.0, 10.0), (0.0, 16.0), (7.0, 10.0)] {
            c.line(V.shallowLight, from: (32, 38), to: (32 + dx, 38 + h))
        }
        for (x, y) in [(20, 24), (44, 23), (31, 50), (24, 46), (40, 46)] { c.rect(V.foam, x, y, 2, 2) }
        return c
    }

    static func cafe(lit: Bool) -> PixelCanvas {
        let c = PixelCanvas(width: 64, height: 64)
        c.polygon(V.shadow, [(32, 0), (64, 16), (32, 32), (0, 16)])
        let front = (32.0, 4.0), right = (58.0, 17.0), left = (6.0, 17.0)
        let wall = 20.0
        c.polygon(V.cafeWall, [left, front, (front.0, front.1 + wall), (left.0, left.1 + wall)])
        c.polygon(V.cafeWallShade, [front, right, (right.0, right.1 + wall), (front.0, front.1 + wall)])
        let glass = lit ? V.windowLit : V.window
        // Big shop window on the left face, door on the right face.
        c.polygon(V.woodDark, [(9, 18), (28, 8.5), (28, 20.5), (9, 30)])
        c.polygon(glass, [(10, 18.5), (27, 10), (27, 20), (10, 28.5)])
        c.polygon(V.woodDark, [(37, 6.5), (44, 10), (44, 22), (37, 18.5)])
        c.polygon(V.woodLight, [(38, 7.5), (43, 10), (43, 21), (38, 18.5)])
        // Striped awning over the door side.
        for stripe in 0..<5 {
            let x0 = 33 + Double(stripe) * 5
            let color = stripe.isMultiple(of: 2) ? V.awning : V.cream
            c.polygon(
                color,
                [
                    (x0, 24 + (x0 - 33) / 2), (x0 + 5, 26.5 + (x0 - 33) / 2), (x0 + 5, 31.5 + (x0 - 33) / 2),
                    (x0, 29 + (x0 - 33) / 2),
                ])
        }
        let eaveL = (2.0, 37.0), eaveF = (32.0, 22.0), eaveR = (62.0, 37.0)
        let ridgeL = (22.0, 52.0), ridgeR = (42.0, 52.0)
        c.polygon(V.cafeRoof, [eaveL, eaveF, ridgeR, ridgeL])
        c.polygon(V.cafeRoofShade, [eaveF, eaveR, ridgeR])
        c.rect(V.woodDark, 26, 52, 12, 7)
        c.rect(V.cream, 27, 53, 10, 5)
        c.rect(V.woodDark, 29, 55, 2, 2)
        c.rect(V.roof, 33, 55, 2, 2)
        return c
    }

    /// A small yellow bird. Same size and feet position as the mochi.
    static func kotori(sleeping: Bool) -> PixelCanvas {
        let c = PixelCanvas(width: 22, height: 20)
        c.ellipse(V.shadow, 4, 1, 14, 5)
        c.ellipse(SKColor(hex: 0xD9A82E), 4, 3, 15, 13)
        c.ellipse(V.petalYellow, 5, 4, 13, 12)
        c.ellipse(V.cream, 7, 4, 9, 5)
        c.ellipse(SKColor(hex: 0xE2B23A), 3, 7, 6, 5)  // wing
        c.polygon(V.apricot, [(17, 10), (21, 9), (17, 8)])  // beak
        if sleeping {
            c.rect(V.ink, 13, 11, 2, 1)
        } else {
            c.rect(V.ink, 14, 11, 1, 2)
        }
        c.rect(V.apricot, 12, 8, 2, 1)
        c.rect(SKColor(hex: 0xD9A82E), 10, 16, 2, 2)  // tuft
        c.rect(V.woodDark, 8, 1, 1, 2)
        c.rect(V.woodDark, 12, 1, 1, 2)
        return c
    }

    /// A young tanuki: brown, darker mask, light belly.
    static func tanuki(sleeping: Bool) -> PixelCanvas {
        let c = PixelCanvas(width: 22, height: 20)
        c.ellipse(V.shadow, 3, 1, 16, 5)
        c.ellipse(SKColor(hex: 0x6B4A33), 2, 3, 18, 14)
        c.ellipse(SKColor(hex: 0x9C7353), 3, 4, 16, 13)
        c.ellipse(V.wall, 7, 4, 8, 6)  // belly
        c.rect(SKColor(hex: 0x6B4A33), 3, 15, 4, 4)  // ears
        c.rect(SKColor(hex: 0x6B4A33), 15, 15, 4, 4)
        c.rect(V.ink, 5, 9, 5, 3)  // mask
        c.rect(V.ink, 12, 9, 5, 3)
        if sleeping {
            c.rect(V.cream, 6, 10, 3, 1)
            c.rect(V.cream, 13, 10, 3, 1)
        } else {
            c.rect(V.cream, 7, 10, 1, 1)
            c.rect(V.cream, 14, 10, 1, 1)
        }
        c.rect(V.ink, 10, 8, 2, 1)  // nose
        c.ellipse(SKColor(hex: 0x6B4A33), 17, 3, 5, 4)  // tail
        c.rect(V.wall, 19, 4, 2, 1)
        return c
    }
}
