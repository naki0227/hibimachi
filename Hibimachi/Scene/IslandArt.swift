import HibimachiCore
import SpriteKit

/// Original code-drawn pixel art (docs/VISUAL-DIRECTION.md direction A, isometric per ADR-0004).
/// One art pixel = `pixel` scene units. Object art is anchored at the footprint's front (bottom) vertex.
/// Replace with hand-made sprite assets later: node names and `ObjectKind` raw values stay stable.
@MainActor
enum IslandArt {
    static let pixel: CGFloat = 2

    enum Palette {
        static let sea = SKColor(hex: 0x3E9DCB)
        static let seaDeep = SKColor(hex: 0x2F86B8)
        static let seaWave = SKColor(hex: 0x6CC2E2)
        static let shallow = SKColor(hex: 0x6FD0D3)
        static let shallowLight = SKColor(hex: 0x9BE3DE)
        static let foam = SKColor(hex: 0xF4FBF8)
        static let grass = SKColor(hex: 0x8FCB6B)
        static let grassAlt = SKColor(hex: 0x86C364)
        static let grassDark = SKColor(hex: 0x6EAA55)
        static let grassLight = SKColor(hex: 0xB2DE86)
        static let path = SKColor(hex: 0xE8CF9C)
        static let pathAlt = SKColor(hex: 0xE0C38C)
        static let stone = SKColor(hex: 0xCDB58A)
        static let stoneLight = SKColor(hex: 0xF4E3BD)
        static let cliffLight = SKColor(hex: 0xC99F78)
        static let cliffDark = SKColor(hex: 0xA77E5C)
        static let cliffShade = SKColor(hex: 0x8A6549)
        static let cream = SKColor(hex: 0xFAF7EF)
        static let wall = SKColor(hex: 0xF3E9D8)
        static let wallShade = SKColor(hex: 0xDCCAB0)
        static let roof = SKColor(hex: 0xE46F4F)
        static let roofShade = SKColor(hex: 0xBE4F3A)
        static let brick = SKColor(hex: 0xA65A44)
        static let window = SKColor(hex: 0x86C5E0)
        static let windowLit = SKColor(hex: 0xFFD27A)
        static let wood = SKColor(hex: 0x9C6B4E)
        static let woodDark = SKColor(hex: 0x7A4F38)
        static let woodLight = SKColor(hex: 0xC08A63)
        static let leaf = SKColor(hex: 0x5DA35A)
        static let leafDark = SKColor(hex: 0x3F7F45)
        static let leafLight = SKColor(hex: 0x8CCB6B)
        static let pine = SKColor(hex: 0x3F8A5A)
        static let pineDark = SKColor(hex: 0x2B6847)
        static let petalPink = SKColor(hex: 0xF3A6B8)
        static let petalWhite = SKColor(hex: 0xFFFDF5)
        static let petalYellow = SKColor(hex: 0xF7D774)
        static let petalPurple = SKColor(hex: 0xC8A2E0)
        static let rock = SKColor(hex: 0xB9B2A6)
        static let rockDark = SKColor(hex: 0x8E887E)
        static let pond = SKColor(hex: 0x5BB6DA)
        static let pondDeep = SKColor(hex: 0x3E98C4)
        static let iron = SKColor(hex: 0x3B3B46)
        static let ink = SKColor(hex: 0x263747)
        static let shadow = SKColor(hex: 0x2E5E3A, alpha: 0.35)
        static let valid = SKColor(hex: 0x79BDD5)
        static let invalid = SKColor(hex: 0xE0705A)
        static let apricot = SKColor(hex: 0xEDAD94)
        static let sakuraDark = SKColor(hex: 0xE38AA5)
        static let sakuraLight = SKColor(hex: 0xFBD3DE)
        static let cafeWall = SKColor(hex: 0xFFF3DC)
        static let cafeWallShade = SKColor(hex: 0xE9D3B2)
        static let cafeRoof = SKColor(hex: 0x5FA77A)
        static let cafeRoofShade = SKColor(hex: 0x468A61)
        static let awning = SKColor(hex: 0x6FB8A0)
    }

    struct Sprite {
        let texture: SKTexture
        let image: CGImage
        /// Anchor in unit coordinates: where the footprint's front vertex sits inside the image.
        let anchor: CGPoint
    }

    private static var cache: [String: Sprite] = [:]

    static func sprite(for kind: ObjectKind, lit: Bool = false) -> Sprite {
        let key = "\(kind.rawValue)-\(lit)"
        if let cached = cache[key] { return cached }
        let (canvas, anchorX): (PixelCanvas, Double) =
            switch kind {
            case .roundTree: (ObjectSprites.roundTree(), 16)
            case .pineTree: (ObjectSprites.pineTree(), 14)
            case .house: (ObjectSprites.house(lit: lit), 32)
            case .bench: (ObjectSprites.bench(), 16)
            case .flower: (ObjectSprites.flowerBush(), 16)
            case .pond: (ObjectSprites.pond(), 32)
            case .lamp: (ObjectSprites.lamp(lit: lit), 8)
            case .sakuraTree: (ObjectSprites.sakuraTree(), 16)
            case .bush: (ObjectSprites.bush(), 16)
            case .rock: (ObjectSprites.rock(), 16)
            case .fence: (ObjectSprites.fence(), 16)
            case .mailbox: (ObjectSprites.mailbox(), 8)
            case .picnicMat: (ObjectSprites.picnicMat(), 16)
            case .birdhouse: (ObjectSprites.birdhouse(), 8)
            case .swing: (ObjectSprites.swing(), 16)
            case .campfire: (ObjectSprites.campfire(lit: lit), 16)
            case .well: (ObjectSprites.well(), 16)
            case .garden: (ObjectSprites.garden(), 32)
            case .fountain: (ObjectSprites.fountain(), 32)
            case .cafe: (ObjectSprites.cafe(lit: lit), 32)
            }
        let sprite = Sprite(
            texture: canvas.makeTexture(), image: canvas.makeImage(),
            anchor: CGPoint(x: anchorX / Double(canvas.width), y: 0))
        cache[key] = sprite
        return sprite
    }

    /// A node for an object; its position must be the footprint's front vertex.
    static func objectNode(_ kind: ObjectKind, lit: Bool = false) -> SKSpriteNode {
        let sprite = sprite(for: kind, lit: lit)
        let node = SKSpriteNode(texture: sprite.texture)
        node.anchorPoint = sprite.anchor
        node.size = CGSize(width: sprite.texture.size().width * pixel, height: sprite.texture.size().height * pixel)
        return node
    }

    static func creatureTexture(_ species: Species = .mochi, sleeping: Bool) -> SKTexture {
        let key = "creature-\(species.rawValue)-\(sleeping)"
        if let cached = cache[key] { return cached.texture }
        let canvas =
            switch species {
            case .mochi: ObjectSprites.creature(sleeping: sleeping)
            case .kotori: ObjectSprites.kotori(sleeping: sleeping)
            case .tanuki: ObjectSprites.tanuki(sleeping: sleeping)
            }
        let texture = canvas.makeTexture()
        cache[key] = Sprite(texture: texture, image: canvas.makeImage(), anchor: CGPoint(x: 0.5, y: 0.1))
        return texture
    }

    /// Resident art for SwiftUI (arrival card, field guide).
    static func creatureImage(_ species: Species) -> CGImage {
        _ = creatureTexture(species, sleeping: false)
        return cache["creature-\(species.rawValue)-false"]?.image ?? ObjectSprites.creature(sleeping: false).makeImage()
    }

    static let glowTexture: SKTexture = {
        let canvas = PixelCanvas(width: 64, height: 64)
        canvas.radialGlow(SKColor(hex: 0xFFD98A, alpha: 0.9))
        let texture = canvas.makeTexture()
        texture.filteringMode = .linear
        return texture
    }()
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
