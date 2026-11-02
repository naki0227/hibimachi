import HibimachiCore
import SpriteKit

/// Goal towers on the islets, the drifting light of the island's mood and the residents' ribbons (ADR-0017).
/// Everything here is derived from progress and settings; nothing is saved.
extension IslandScene {
    /// Islets in the open sea at the corners of the map's bounding box (x, y as a share of the map; size).
    static let isletSpots: [(x: CGFloat, y: CGFloat, size: CGFloat)] = [
        (0.12, 0.84, 2.0), (0.88, 0.86, 1.6), (0.1, 0.16, 1.4), (0.9, 0.12, 2.2), (0.27, 0.96, 1.6),
    ]

    private static let lookLayerName = "goal-towers"

    private var lookLayer: SKNode {
        if let layer = backdropLayer.childNode(withName: Self.lookLayerName) { return layer }
        let layer = SKNode()
        layer.name = Self.lookLayerName
        layer.zPosition = 1
        backdropLayer.addChild(layer)
        return layer
    }

    /// Rebuilds the towers when a goal, its steps or the flag color changed. Called a few times a second.
    func syncLook() {
        let monuments = GoalMonument.all(in: store.progress)
        let mood = IslandMood.leaning(in: store.progress, today: store.today)
        let key =
            monuments.map { "\($0.goalID)-\($0.stage)-\($0.category.rawValue)" }.joined(separator: ",")
            + "|\(favoriteColor.rawValue)|\(mood?.rawValue ?? "-")"
        // Newcomers get the ribbon too; the node skips it when nothing changed.
        for node in residentNodes.values { node.setRibbon(favoriteColor.color) }
        let layer = lookLayer
        guard layer.userData?["key"] as? String != key else { return }
        layer.userData = NSMutableDictionary(dictionary: ["key": key, "mood": mood?.rawValue ?? ""])
        layer.removeAllChildren()
        let size = grid.mapSize
        for (index, monument) in monuments.enumerated() where index < Self.isletSpots.count {
            let spot = Self.isletSpots[index]
            let scale = spot.size * IslandArt.pixel / 2
            let tower = SKSpriteNode(
                texture: MonumentArt.texture(
                    stage: monument.stage, category: monument.category, flag: favoriteColor.color))
            tower.anchorPoint = CGPoint(x: 0.5, y: 0)
            tower.size = CGSize(width: CGFloat(MonumentArt.width) * scale, height: CGFloat(MonumentArt.height) * scale)
            // On the islet's grass, left of its tree.
            tower.position = CGPoint(x: size.width * spot.x - 6 * scale, y: size.height * spot.y - 2 * scale)
            tower.name = "goal-tower-\(index)"
            layer.addChild(tower)
        }
    }

    /// A small light rising from the island in the color of its mood; nothing when there is no leaning.
    func spawnMoodMote() {
        guard !reduceMotion, let raw = lookLayer.userData?["mood"] as? String,
            let category = GoalCategory(rawValue: raw), let tile = landTiles.randomElement()
        else { return }
        let center = grid.center(of: tile)
        let mote = SKSpriteNode(color: MonumentArt.moodColor(category), size: CGSize(width: 3, height: 3))
        mote.position = CGPoint(x: center.x + Double.random(in: -12...12), y: center.y + Double.random(in: 4...16))
        mote.alpha = 0
        mote.zPosition = 845
        addChild(mote)
        mote.run(
            .sequence([
                .group([.fadeAlpha(to: 0.9, duration: 0.6), .moveBy(x: 0, y: 14, duration: 0.6)]),
                .group([.fadeOut(withDuration: 1.4), .moveBy(x: Double.random(in: -6...6), y: 22, duration: 1.4)]),
                .removeFromParent(),
            ]))
    }

    private var landTiles: [TileCoord] {
        let world = store.world
        return (0..<world.height).flatMap { y in
            (0..<world.width).compactMap { x in
                let tile = TileCoord(x: x, y: y)
                return world.terrain(at: tile) == .grass ? tile : nil
            }
        }
    }
}
