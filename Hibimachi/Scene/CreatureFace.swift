import SpriteKit

/// Residents' expressions (TODO 住人の表情の種類). Normal and sleepy are each species' own art; happy and surprised
/// are drawn over the same eye positions so every species shares them.
enum CreatureFace: String, CaseIterable {
    case normal
    case sleepy
    /// Enjoying something or being petted: eyes as little arcs.
    case happy
    /// A reaction cut short, or something unexpected: round eyes and a small mouth.
    case surprised

    /// Eyes centered on the given columns, around row `y` (art pixels).
    static func drawEyes(_ face: CreatureFace, on c: PixelCanvas, centers: [Int], y: Int, color: SKColor) {
        for x in centers {
            switch face {
            case .happy:
                c.pixel(color, x - 1, y)
                c.pixel(color, x, y + 1)
                c.pixel(color, x + 1, y)
            case .surprised:
                c.rect(color, x - 1, y, 2, 2)
                c.pixel(color, x, y + 2)
            case .normal, .sleepy:
                c.rect(color, x, y, 1, 2)
            }
        }
    }

    /// A small mouth for the expressive faces; none otherwise (the plain faces have no mouth).
    static func drawMouth(_ face: CreatureFace, on c: PixelCanvas, x: Int, y: Int, color: SKColor) {
        switch face {
        case .happy:
            c.pixel(color, x, y)
            c.pixel(color, x + 1, y)
        case .surprised:
            c.rect(color, x, y - 1, 2, 2)
        case .normal, .sleepy:
            break
        }
    }
}
