import HibimachiCore
import SpriteKit

/// Purely cosmetic parts of the scene: backdrop islets, water sparkles, day/night tint and lights,
/// discovery effects. None of this affects game state.
extension IslandScene {
    func buildBackdrop() {
        let size = grid.mapSize
        // The corners of the map's bounding box are open sea: a few distant islets live there.
        let spots: [(CGFloat, CGFloat, CGFloat)] = [
            (0.12, 0.84, 2.0), (0.88, 0.86, 1.6), (0.1, 0.16, 1.4), (0.9, 0.12, 2.2),
        ]
        for (index, spot) in spots.enumerated() {
            let islet = SKSpriteNode(texture: TerrainArt.isletTexture(variant: index))
            islet.size = CGSize(width: 40 * spot.2 * IslandArt.pixel / 2, height: 30 * spot.2 * IslandArt.pixel / 2)
            islet.position = CGPoint(x: size.width * spot.0, y: size.height * spot.1)
            islet.alpha = 0.9
            backdropLayer.addChild(islet)
        }
    }

    func buildGridOverlay() {
        let path = CGMutablePath()
        for column in 0...grid.columns {
            path.move(to: grid.point(x: Double(column), y: 0).cgPoint)
            path.addLine(to: grid.point(x: Double(column), y: Double(grid.rows)).cgPoint)
        }
        for row in 0...grid.rows {
            path.move(to: grid.point(x: 0, y: Double(row)).cgPoint)
            path.addLine(to: grid.point(x: Double(grid.columns), y: Double(row)).cgPoint)
        }
        let lines = SKShapeNode(path: path)
        lines.strokeColor = IslandArt.Palette.ink.withAlphaComponent(0.14)
        lines.lineWidth = 1.5
        gridOverlay.addChild(lines)
        gridOverlay.isHidden = true
    }

    func spawnSparkle() {
        guard !reduceMotion, let tile = waterTiles.randomElement() else { return }
        let center = grid.center(of: tile)
        let sparkle = SKSpriteNode(color: IslandArt.Palette.foam, size: CGSize(width: 6, height: 2))
        sparkle.position = CGPoint(
            x: center.x + Double.random(in: -14...14), y: center.y - 20 + Double.random(in: -4...4))
        sparkle.alpha = 0
        sparkle.zPosition = -1
        addChild(sparkle)
        sparkle.run(.sequence([.fadeAlpha(to: 0.8, duration: 0.4), .fadeOut(withDuration: 0.9), .removeFromParent()]))
    }

    func refreshDayPhase() {
        let phase = dayPhaseOverride ?? DayPhase(hour: Calendar.current.component(.hour, from: Date()))
        guard phase != dayPhase || !dayPhaseApplied else { return }
        dayPhase = phase
        dayPhaseApplied = true
        let (color, alpha): (SKColor, CGFloat) =
            switch phase {
            case .morning: (SKColor(hex: 0xFFC48A), 0.12)
            case .day: (.clear, 0)
            case .evening: (SKColor(hex: 0xFF8A5B), 0.18)
            case .night: (SKColor(hex: 0x1E2F6B), 0.36)
            }
        tint.color = color
        tint.run(.fadeAlpha(to: alpha, duration: reduceMotion ? 0 : 1.2))
        applyLights()
    }

    /// Lamps and house windows switch to lit art and get a soft glow in the evening and at night.
    func applyLights() {
        glowLayer.removeAllChildren()
        let lit = dayPhase.lightsOn
        for object in store.world.objects where object.kind == .lamp || object.kind == .house {
            guard let node = objectNodes[object.id] else { continue }
            node.texture = IslandArt.sprite(for: object.kind, lit: lit).texture
            guard lit else { continue }
            let glow = SKSpriteNode(texture: IslandArt.glowTexture)
            glow.blendMode = .add
            let front = grid.frontVertex(at: object.origin)
            if object.kind == .lamp {
                glow.size = CGSize(width: 110, height: 110)
                glow.position = CGPoint(x: front.x, y: front.y + 80)
            } else {
                glow.size = CGSize(width: 170, height: 120)
                glow.position = CGPoint(x: front.x, y: front.y + 34)
            }
            glow.alpha = 0.5
            glowLayer.addChild(glow)
        }
    }

    func handle(_ events: [WorldEvent]) {
        for event in events {
            switch event {
            case .reactionInterrupted:
                creatureNode.flash("?", reduceMotion: reduceMotion)
            case .discovered(let kind):
                sparkle(at: creatureNode.position)
                captureDiscovery(kind)
            case .creatureMoved, .reactionStarted:
                break
            }
        }
    }

    private func sparkle(at point: CGPoint) {
        guard !reduceMotion else { return }
        for index in 0..<8 {
            let star = SKSpriteNode(color: IslandArt.Palette.petalYellow, size: CGSize(width: 4, height: 4))
            star.position = CGPoint(x: point.x, y: point.y + 30)
            star.zPosition = 950
            addChild(star)
            let angle = Double(index) / 8 * 2 * .pi
            let move = SKAction.moveBy(x: cos(angle) * 34, y: sin(angle) * 34, duration: 0.6)
            star.run(.sequence([.group([move, .fadeOut(withDuration: 0.6)]), .removeFromParent()]))
        }
    }

    /// Takes a small picture of the creature reacting, for the discovery card and the field guide.
    private func captureDiscovery(_ kind: ReactionKind) {
        Task { @MainActor [weak self] in
            // Wait for the creature to settle into its pose before taking the picture.
            try? await Task.sleep(for: .milliseconds(800))
            guard let self, let view = self.view,
                let full = view.texture(from: self.worldLayer)?.cgImage()
            else { return }
            // Render the island layer (no tint/UI overlays) and crop around the creature ourselves:
            // the rendered image covers the layer's accumulated frame, top-left origin.
            let frame = self.worldLayer.calculateAccumulatedFrame()
            let scale = Double(full.width) / frame.width
            let center = self.creatureNode.position
            let crop = CGRect(
                x: (center.x - 90 - frame.minX) * scale, y: (frame.maxY - (center.y + 110)) * scale,
                width: 180 * scale, height: 150 * scale)
            guard let image = full.cropping(to: crop) else { return }
            self.onDiscoverySnapshot?(kind, image)
        }
    }
}
