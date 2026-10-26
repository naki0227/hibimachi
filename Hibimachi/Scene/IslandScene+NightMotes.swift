import HibimachiCore
import SpriteKit

/// Small lights for the night discoveries: fireflies over a pond, little lights drawn to a lamp.
enum NightMotes {
    static func color(for kind: ReactionKind) -> SKColor? {
        switch kind {
        case .fireflies: SKColor(hex: 0xD8F27A)
        case .lampGlow: IslandArt.Palette.petalYellow
        default: nil
        }
    }

    static let count = 7
    /// Roughly the length of the reaction (12–16 ticks).
    static let lifetime: TimeInterval = 9
}

extension IslandScene {
    /// Blinking, drifting dots around an object for a few seconds. With Reduce Motion they only fade in and out.
    func showMotes(around point: CGPoint, color: SKColor) {
        for index in 0..<NightMotes.count {
            let mote = SKSpriteNode(color: color, size: CGSize(width: 3, height: 3))
            let angle = Double(index) / Double(NightMotes.count) * 2 * .pi
            mote.position = CGPoint(x: point.x + cos(angle) * 22, y: point.y + 24 + sin(angle) * 12)
            mote.zPosition = 940
            mote.alpha = 0
            mote.blendMode = .add
            addChild(mote)
            let blink = SKAction.sequence([
                .fadeAlpha(to: 0.9, duration: 0.5 + Double(index % 3) * 0.2), .fadeAlpha(to: 0.2, duration: 0.6),
            ])
            let drift: SKAction =
                reduceMotion
                ? .wait(forDuration: 1.1)
                : .moveBy(x: CGFloat((index % 3) - 1) * 6, y: CGFloat((index % 2) * 2 - 1) * 5, duration: 1.1)
            let life = SKAction.repeat(.group([blink, .sequence([drift, drift.reversed()])]), count: 4)
            mote.run(
                .sequence([
                    .wait(forDuration: Double(index) * 0.15), life, .fadeOut(withDuration: 0.6), .removeFromParent(),
                ]))
        }
    }
}
