import HibimachiCore
import SpriteKit

/// Far scenery in the open sea (TODO "遠景の灯台・船"): a lighthouse on a rock and a little boat drifting back
/// and forth. Decoration only; nothing here reacts to the game.
extension IslandScene {
    func buildScenery() {
        let size = grid.mapSize
        let scale = IslandArt.pixel / 2 * 1.6

        let lighthouse = SKSpriteNode(texture: SceneryArt.lighthouse)
        lighthouse.anchorPoint = CGPoint(x: 0.5, y: 0)
        lighthouse.size = CGSize(width: 14 * scale, height: 30 * scale)
        lighthouse.position = CGPoint(x: size.width * 0.95, y: size.height * 0.66)
        lighthouse.name = "scenery-lighthouse"
        backdropLayer.addChild(lighthouse)
        let lamp = SKSpriteNode(color: IslandArt.Palette.windowLit, size: CGSize(width: 4 * scale, height: 3 * scale))
        lamp.position = CGPoint(x: 0, y: 23.5 * scale)
        lamp.zPosition = 1
        lighthouse.addChild(lamp)

        let boat = SKSpriteNode(texture: SceneryArt.boat)
        boat.anchorPoint = CGPoint(x: 0.5, y: 0)
        boat.size = CGSize(width: 16 * scale, height: 14 * scale)
        boat.position = CGPoint(x: size.width * 0.05, y: size.height * 0.06)
        boat.name = "scenery-boat"
        backdropLayer.addChild(boat)

        guard !reduceMotion else { return }
        lamp.run(.repeatForever(.sequence([.fadeAlpha(to: 0.35, duration: 1.4), .fadeAlpha(to: 1, duration: 1.4)])))
        let across = size.width * 0.25
        let sail = SKAction.sequence([
            .moveBy(x: across, y: 0, duration: 40),
            .run { [weak boat] in boat?.xScale = -1 },
            .moveBy(x: -across, y: 0, duration: 40),
            .run { [weak boat] in boat?.xScale = 1 },
        ])
        let bob = SKAction.sequence([.moveBy(x: 0, y: 2, duration: 1.2), .moveBy(x: 0, y: -2, duration: 1.2)])
        boat.run(.repeatForever(sail))
        boat.run(.repeatForever(bob))
    }
}

@MainActor
enum SceneryArt {
    private typealias P = IslandArt.Palette

    static let lighthouse: SKTexture = {
        let c = PixelCanvas(width: 14, height: 30)
        c.ellipse(P.rockDark, 0, 0, 14, 6)
        c.ellipse(P.rock, 1, 1, 12, 4)
        // Tapering tower with red bands.
        for row in 0..<17 {
            let inset = row / 6
            let color = (row / 4).isMultiple(of: 2) ? P.cream : P.roof
            c.rect(color, 4 + inset, 4 + row, 6 - inset * 2, 1)
        }
        c.rect(P.woodDark, 4, 21, 6, 1)
        c.rect(P.window, 5, 22, 4, 3)
        c.polygon(P.roofShade, [(3, 25), (11, 25), (7, 29)])
        return c.makeTexture()
    }()

    static let boat: SKTexture = {
        let c = PixelCanvas(width: 16, height: 14)
        c.polygon(P.woodDark, [(1, 3), (15, 3), (13, 0), (3, 0)])
        c.rect(P.wood, 2, 3, 12, 1)
        c.rect(P.woodDark, 7, 4, 1, 9)
        c.polygon(P.cream, [(8, 5), (8, 13), (14, 5)])
        c.polygon(P.stoneLight, [(6, 5), (6, 11), (2, 5)])
        return c.makeTexture()
    }()
}
