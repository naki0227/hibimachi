import HibimachiCore
import SpriteKit

/// Code-drawn goal towers (ADR-0017): a stone foundation that grows a stage per share of finished steps,
/// and a roof with a flag when every step is done. The body takes the goal category's color.
@MainActor
enum MonumentArt {
    static let width = 18
    static let height = 34

    private static var cache: [String: SKTexture] = [:]

    static func texture(stage: Int, category: GoalCategory, flag: SKColor?) -> SKTexture {
        let flagColor = flag ?? bodyColor(category).shade
        let key = "\(stage)-\(category.rawValue)-\(flagColor.description)"
        if let cached = cache[key] { return cached }
        let c = PixelCanvas(width: width, height: height)
        let body = bodyColor(category)
        // Foundation stones: always there, the promise of a tower.
        c.rect(IslandArt.Palette.rockDark, 2, 0, 14, 3)
        c.rect(IslandArt.Palette.rock, 3, 1, 12, 2)
        let levels = min(max(stage, 0), GoalMonument.maxStage)
        if levels == 0 {
            c.rect(IslandArt.Palette.rock, 4, 3, 3, 2)
            c.rect(IslandArt.Palette.rockDark, 11, 3, 3, 2)
        }
        let storyHeight = 6
        for story in 0..<min(levels, 3) {
            let y = 3 + story * storyHeight
            c.rect(body.shade, 4, y, 10, storyHeight)
            c.rect(body.color, 4, y, 8, storyHeight)
            c.rect(IslandArt.Palette.window, 7, y + 2, 2, 2)
            c.rect(body.shade, 4, y + storyHeight - 1, 10, 1)
        }
        let top = 3 + min(levels, 3) * storyHeight
        if levels >= GoalMonument.maxStage {
            // Roof and flag: the goal is done.
            c.polygon(IslandArt.Palette.roofShade, [(2, Double(top)), (16, Double(top)), (9, Double(top + 7))])
            c.polygon(IslandArt.Palette.roof, [(2, Double(top)), (9, Double(top)), (9, Double(top + 7))])
            c.rect(IslandArt.Palette.woodDark, 9, top + 6, 1, 7)
            c.rect(flagColor, 10, top + 9, 5, 4)
        } else if levels > 0 {
            // Scaffolding and a small pennant while it is being built.
            c.rect(IslandArt.Palette.woodLight, 3, top, 1, 4)
            c.rect(IslandArt.Palette.woodLight, 14, top, 1, 4)
            c.rect(IslandArt.Palette.woodLight, 3, top + 3, 12, 1)
            c.rect(IslandArt.Palette.woodDark, 9, top, 1, 6)
            c.rect(flagColor, 10, top + 3, 3, 2)
        }
        let texture = c.makeTexture()
        cache[key] = texture
        return texture
    }

    private static func bodyColor(_ category: GoalCategory) -> (color: SKColor, shade: SKColor) {
        switch category {
        case .tidy: (SKColor(hex: 0xBFE3EE), SKColor(hex: 0x8CC3D6))
        case .study: (SKColor(hex: 0xF2D27A), SKColor(hex: 0xD3AE52))
        case .rest: (SKColor(hex: 0xC9D3F2), SKColor(hex: 0x9FAEDB))
        case .create: (SKColor(hex: 0xF6C0CC), SKColor(hex: 0xDE94A6))
        case .move: (SKColor(hex: 0xA9DB8A), SKColor(hex: 0x7EBB63))
        case .other: (SKColor(hex: 0xE6D3B3), SKColor(hex: 0xC4AC86))
        }
    }

    /// The light that drifts over the island when it leans towards a category.
    static func moodColor(_ category: GoalCategory) -> SKColor {
        switch category {
        case .tidy: SKColor(hex: 0xFFFFFF)
        case .study: SKColor(hex: 0xFFD866)
        case .rest: SKColor(hex: 0xA8D8FF)
        case .create: SKColor(hex: 0xFF9EC4)
        case .move: SKColor(hex: 0xB6F08A)
        case .other: SKColor(hex: 0xFFE9B8)
        }
    }
}
