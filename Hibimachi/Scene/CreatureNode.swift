import HibimachiCore
import SpriteKit

/// Renders the creature's position, pose and emotes. Holds no rules: it only mirrors `Creature` state.
@MainActor
final class CreatureNode: SKNode {
    private let body = IslandArt.creatureBody()
    private let emote = SKLabelNode(fontNamed: "HiraginoSans-W6")
    private var shownActivityKey = ""
    /// Last position we started moving to. Starting a new move only when it changes matters:
    /// restarting the action every frame means SpriteKit never advances it and the creature looks frozen.
    private(set) var movingTarget: CGPoint?

    override init() {
        super.init()
        name = "creature"
        addChild(body)
        emote.fontSize = 13
        emote.fontColor = IslandArt.Palette.ink
        emote.position = CGPoint(x: 0, y: 30)
        emote.alpha = 0
        addChild(emote)
        zPosition = 10
    }

    @available(*, unavailable)
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) is not supported")
    }

    func show(_ creature: Creature, in world: World, geometry: GridGeometry, animated: Bool, reduceMotion: Bool) {
        var target = geometry.center(of: creature.position).cgPoint
        target.y -= CGFloat(geometry.tileSize) * 0.3
        // While reacting, lean half a tile towards the object so the interaction reads clearly.
        if case .interacting(_, let id, _) = creature.activity, let object = world.object(withID: id) {
            let objectCenter = geometry.center(of: object.kind.footprint, at: object.origin).cgPoint
            target.x += (objectCenter.x - target.x) * 0.3
            target.y += (objectCenter.y - target.y) * 0.2
        }
        if target != movingTarget {
            movingTarget = target
            removeAction(forKey: "move")
            if animated {
                run(.move(to: target, duration: 0.4), withKey: "move")
                if !reduceMotion && creature.activity.reaction == nil { hop(height: 3) }
            } else {
                position = target
            }
        }
        showPose(for: creature.activity, reduceMotion: reduceMotion)
    }

    /// Short, one-off emote (e.g. "?" when its target vanished, "!" when tapped).
    func flash(_ text: String, reduceMotion: Bool) {
        emote.text = text
        emote.removeAllActions()
        emote.alpha = 1
        emote.run(.sequence([.wait(forDuration: 1.2), .fadeOut(withDuration: 0.3)]))
        if !reduceMotion { hop(height: 6) }
    }

    private func showPose(for activity: CreatureActivity, reduceMotion: Bool) {
        let key: String
        if case .interacting(let kind, _, _) = activity { key = kind.rawValue } else { key = "" }
        guard key != shownActivityKey else { return }
        shownActivityKey = key
        body.removeAction(forKey: "pose")
        body.yScale = 1
        body.xScale = 1
        guard case .interacting(let kind, _, _) = activity else {
            emote.run(.fadeOut(withDuration: 0.3))
            return
        }
        emote.removeAllActions()
        emote.text = kind.emote
        emote.alpha = 1
        switch kind {
        case .treeNap:
            body.yScale = 0.8
        case .benchRest, .bloomBench, .pondVisit:
            break
        }
        guard !reduceMotion else { return }
        let bob = SKAction.sequence([
            .scaleY(to: body.yScale * 0.94, duration: 0.6), .scaleY(to: body.yScale, duration: 0.6),
        ])
        body.run(.repeatForever(bob), withKey: "pose")
    }

    private func hop(height: CGFloat) {
        body.removeAction(forKey: "hop")
        body.position = .zero
        body.run(
            .sequence([.moveBy(x: 0, y: height, duration: 0.12), .moveBy(x: 0, y: -height, duration: 0.12)]),
            withKey: "hop")
    }
}

extension ScenePoint {
    var cgPoint: CGPoint { CGPoint(x: x, y: y) }
}

extension CGPoint {
    var scenePoint: ScenePoint { ScenePoint(x: Double(x), y: Double(y)) }
}
