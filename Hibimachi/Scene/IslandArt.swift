import HibimachiCore
import SpriteKit

/// Placeholder "soft pixel" art built from colored rectangles (docs/VISUAL-DIRECTION.md, direction A palette).
/// Each tile is a 16×16 grid of 2pt "pixels". Replace with original sprite assets later; node names stay stable.
enum IslandArt {
    static let pixel: CGFloat = 2

    enum Palette {
        static let water = SKColor(hex: 0x79BDD5)
        static let waterDeep = SKColor(hex: 0x5FA7C2)
        static let grass = SKColor(hex: 0x91BFA0)
        static let grassLight = SKColor(hex: 0x9DC8AA)
        static let path = SKColor(hex: 0xF5D99B)
        static let pathDark = SKColor(hex: 0xE9C985)
        static let cream = SKColor(hex: 0xFAF7EF)
        static let apricot = SKColor(hex: 0xEDAD94)
        static let ink = SKColor(hex: 0x263747)
        static let leaf = SKColor(hex: 0x5E9A72)
        static let leafDark = SKColor(hex: 0x4A7F5C)
        static let wood = SKColor(hex: 0x9C6B4E)
        static let woodLight = SKColor(hex: 0xC08A63)
        static let roof = SKColor(hex: 0xD9785F)
        static let petal = SKColor(hex: 0xF3A6B8)
        static let valid = SKColor(hex: 0x79BDD5)
        static let invalid = SKColor(hex: 0xE0705A)
    }

    /// A rectangle in "pixel" units relative to the bottom-left of a node's footprint.
    static func px(_ x: Int, _ y: Int, _ w: Int, _ h: Int, _ color: SKColor) -> SKSpriteNode {
        let node = SKSpriteNode(color: color, size: CGSize(width: CGFloat(w) * pixel, height: CGFloat(h) * pixel))
        node.anchorPoint = .zero
        node.position = CGPoint(x: CGFloat(x) * pixel, y: CGFloat(y) * pixel)
        return node
    }

    static func terrainTile(_ terrain: Terrain, at tile: TileCoord, size: CGFloat) -> SKSpriteNode {
        let checker = (tile.x + tile.y).isMultiple(of: 2)
        let color: SKColor =
            switch terrain {
            case .grass: checker ? Palette.grass : Palette.grassLight
            case .path: checker ? Palette.path : Palette.pathDark
            case .water: checker ? Palette.water : Palette.waterDeep
            }
        let node = SKSpriteNode(color: color, size: CGSize(width: size, height: size))
        node.anchorPoint = .zero
        node.position = CGPoint(x: CGFloat(tile.x) * size, y: CGFloat(tile.y) * size)
        return node
    }

    /// Object art with its origin at the footprint's bottom-left corner.
    static func objectNode(_ kind: ObjectKind) -> SKNode {
        let node = SKNode()
        let parts: [SKSpriteNode] =
            switch kind {
            case .roundTree:
                [
                    px(4, 0, 8, 2, Palette.leafDark.withAlphaComponent(0.4)), px(7, 1, 2, 5, Palette.wood),
                    px(3, 5, 10, 7, Palette.leaf), px(4, 12, 8, 2, Palette.leaf), px(2, 7, 1, 3, Palette.leaf),
                    px(13, 7, 1, 3, Palette.leaf), px(5, 9, 2, 2, Palette.grassLight),
                ]
            case .pineTree:
                [
                    px(4, 0, 8, 2, Palette.leafDark.withAlphaComponent(0.4)), px(7, 1, 2, 3, Palette.wood),
                    px(3, 3, 10, 3, Palette.leafDark), px(4, 6, 8, 3, Palette.leafDark),
                    px(5, 9, 6, 3, Palette.leafDark),
                    px(6, 12, 4, 2, Palette.leafDark), px(7, 14, 2, 1, Palette.leafDark), px(5, 7, 2, 1, Palette.leaf),
                ]
            case .house:
                [
                    px(3, 0, 26, 2, Palette.leafDark.withAlphaComponent(0.35)), px(4, 1, 24, 14, Palette.cream),
                    px(2, 15, 28, 3, Palette.roof), px(4, 18, 24, 3, Palette.roof), px(7, 21, 18, 3, Palette.roof),
                    px(11, 24, 10, 2, Palette.roof), px(13, 1, 6, 9, Palette.wood), px(17, 5, 1, 1, Palette.path),
                    px(6, 7, 5, 4, Palette.water), px(21, 7, 5, 4, Palette.water), px(22, 24, 3, 5, Palette.woodLight),
                ]
            case .bench:
                [
                    px(2, 0, 12, 1, Palette.leafDark.withAlphaComponent(0.35)), px(3, 1, 1, 4, Palette.wood),
                    px(12, 1, 1, 4, Palette.wood), px(2, 5, 12, 2, Palette.woodLight),
                    px(2, 9, 12, 2, Palette.woodLight),
                    px(3, 7, 1, 2, Palette.wood), px(12, 7, 1, 2, Palette.wood),
                ]
            case .flower:
                [
                    px(7, 1, 2, 6, Palette.leafDark), px(9, 3, 2, 2, Palette.leaf), px(6, 7, 4, 4, Palette.petal),
                    px(5, 8, 6, 2, Palette.petal), px(7, 8, 2, 2, Palette.path),
                ]
            case .pond:
                [
                    px(3, 2, 26, 26, Palette.cream), px(2, 4, 28, 22, Palette.cream), px(4, 3, 24, 24, Palette.water),
                    px(3, 5, 26, 20, Palette.water), px(8, 8, 16, 12, Palette.waterDeep),
                    px(10, 20, 6, 1, Palette.cream),
                    px(20, 10, 3, 3, Palette.leaf),
                ]
            }
        parts.forEach(node.addChild)
        return node
    }

    /// The creature: a round cream blob with apricot cheeks. Anchored at its feet center.
    static func creatureBody() -> SKNode {
        let body = SKNode()
        [
            px(-5, -1, 10, 1, Palette.leafDark.withAlphaComponent(0.4)), px(-5, 0, 10, 8, Palette.cream),
            px(-6, 1, 12, 6, Palette.cream), px(-4, 8, 8, 2, Palette.cream), px(-3, 10, 2, 2, Palette.cream),
            px(1, 10, 2, 2, Palette.cream), px(-3, 4, 1, 2, Palette.ink), px(2, 4, 1, 2, Palette.ink),
            px(-5, 3, 2, 1, Palette.apricot), px(3, 3, 2, 1, Palette.apricot),
        ].forEach(body.addChild)
        return body
    }
}

extension SKColor {
    convenience init(hex: UInt32, alpha: CGFloat = 1) {
        self.init(
            red: CGFloat((hex >> 16) & 0xFF) / 255,
            green: CGFloat((hex >> 8) & 0xFF) / 255,
            blue: CGFloat(hex & 0xFF) / 255,
            alpha: alpha
        )
    }
}
