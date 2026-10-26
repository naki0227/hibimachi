import HibimachiCore
import QuartzCore
import SpriteKit

/// Renders a resident's position, pose and emotes. Holds no rules: it only mirrors `Creature` state.
@MainActor
final class CreatureNode: SKNode {
    let species: Species
    private let body: SKSpriteNode
    private let emote = SKLabelNode(fontNamed: "HiraginoSans-W6")
    private var shownActivityKey = ""
    /// When the next friendly gesture is due (seconds, `CACurrentMediaTime` clock).
    private var nextCheerAt: TimeInterval?
    /// Last position we started moving to. Starting a new move only when it changes matters:
    /// restarting the action every frame means SpriteKit never advances it and the creature looks frozen.
    private(set) var movingTarget: CGPoint?

    init(species: Species) {
        self.species = species
        body = SKSpriteNode(texture: IslandArt.creatureTexture(species, sleeping: false))
        super.init()
        name = "creature-\(species.rawValue)"
        body.anchorPoint = CGPoint(x: 0.5, y: 0.1)
        // Drawn 1.5x so the creature reads at the default zoom (its art pixels are slightly larger than the world's).
        body.size = CGSize(width: 22 * IslandArt.pixel * 1.5, height: 20 * IslandArt.pixel * 1.5)
        addChild(body)
        emote.fontSize = 18
        emote.fontColor = IslandArt.Palette.ink
        emote.position = CGPoint(x: 8, y: 62)
        emote.alpha = 0
        addChild(emote)
    }

    @available(*, unavailable)
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) is not supported")
    }

    func show(_ creature: Creature, in world: World, grid: IsoGrid, animated: Bool, reduceMotion: Bool) {
        var target = grid.center(of: creature.position).cgPoint
        // While reacting, lean towards the object so the interaction reads clearly.
        if case .interacting(_, let id, _) = creature.activity, let object = world.object(withID: id) {
            let objectCenter = grid.center(of: object.kind.footprint, at: object.origin).cgPoint
            target.x += (objectCenter.x - target.x) * 0.3
            target.y += (objectCenter.y - target.y) * 0.3
        }
        zPosition = CGFloat(grid.depth(of: Footprint(width: 1, height: 1), at: creature.position)) * 10 + 5
        if target != movingTarget {
            if let previous = movingTarget { body.xScale = target.x < previous.x ? -1 : 1 }
            movingTarget = target
            removeAction(forKey: "move")
            if animated {
                run(.move(to: target, duration: 0.4), withKey: "move")
                if !reduceMotion && creature.activity.reaction == nil { hop(height: 4) }
            } else {
                position = target
            }
        }
        showPose(for: creature.activity, reduceMotion: reduceMotion)
        let idle = if case .idle = creature.activity { true } else { false }
        showFriendship(creature.friendship.level, idle: idle, reduceMotion: reduceMotion)
    }

    /// Feedback for a tap: a heart when it counted toward friendship, a happy note otherwise.
    func showPet(_ outcome: PetOutcome, reduceMotion: Bool) {
        switch outcome {
        case .counted(let level, _): flash(level == .bestFriend ? "♡♡" : "♡", reduceMotion: reduceMotion)
        case .notCounted: flash("♪", reduceMotion: reduceMotion)
        case .unknownResident: break
        }
    }

    /// Closer residents now and then do a little double hop while idle (best friends add a heart).
    /// Called every frame; the gesture is scheduled by time and skipped while the resident is busy.
    private func showFriendship(_ level: Friendship.Level, idle: Bool, reduceMotion: Bool) {
        guard level >= .friend, !reduceMotion else { return }
        let now = CACurrentMediaTime()
        let interval: ClosedRange<TimeInterval> = level == .bestFriend ? 6...12 : 10...20
        guard let due = nextCheerAt else {
            nextCheerAt = now + .random(in: interval)
            return
        }
        guard now >= due, idle else { return }
        nextCheerAt = now + .random(in: interval)
        body.removeAction(forKey: "hop")
        body.position = .zero
        let up = SKAction.moveBy(x: 0, y: 5, duration: 0.12)
        let down = SKAction.moveBy(x: 0, y: -5, duration: 0.12)
        body.run(.sequence([up, down, up, down]), withKey: "hop")
        if level == .bestFriend, emote.alpha == 0 { flash("♡", reduceMotion: true) }
    }

    /// Short, one-off emote (e.g. "?" when its target vanished, a heart when petted).
    func flash(_ text: String, reduceMotion: Bool) {
        emote.text = text
        emote.removeAllActions()
        emote.alpha = 1
        emote.run(.sequence([.wait(forDuration: 1.2), .fadeOut(withDuration: 0.3)]))
        if !reduceMotion { hop(height: 8) }
    }

    private func showPose(for activity: CreatureActivity, reduceMotion: Bool) {
        let key: String
        if case .interacting(let kind, _, _) = activity { key = kind.rawValue } else { key = "" }
        guard key != shownActivityKey else { return }
        shownActivityKey = key
        body.removeAction(forKey: "pose")
        body.yScale = 1
        guard case .interacting(let kind, _, _) = activity else {
            body.texture = IslandArt.creatureTexture(species, sleeping: false)
            emote.run(.fadeOut(withDuration: 0.3))
            return
        }
        emote.removeAllActions()
        emote.text = kind.emote
        emote.alpha = 1
        body.texture = IslandArt.creatureTexture(species, sleeping: kind.looksSleepy)
        guard !reduceMotion else { return }
        let breathe = SKAction.sequence([.scaleY(to: 0.94, duration: 0.7), .scaleY(to: 1, duration: 0.7)])
        body.run(.repeatForever(breathe), withKey: "pose")
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
