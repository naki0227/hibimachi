import HibimachiCore
import SpriteKit
import UIKit

/// Draws `GameStore` state and forwards input to it. No game rules live here:
/// placement checks, reactions and saving are all in HibimachiCore.
@MainActor
final class IslandScene: SKScene {
    static let tileSize = 32.0
    /// Real seconds per simulation tick. One creature step per tick.
    static let tickInterval: TimeInterval = 0.45

    let store: GameStore
    let geometry: GridGeometry
    let cameraBounds: CameraBounds
    let cameraNode = SKCameraNode()
    let creatureNode = CreatureNode()

    private let terrainLayer = SKNode()
    private let objectLayer = SKNode()
    private let overlayLayer = SKNode()
    private let gridOverlay = SKNode()
    private(set) var objectNodes: [UUID: SKNode] = [:]
    private var previewNode: SKNode?
    private var selectionNode: SKNode?

    private var renderedRevision = -1
    private var renderedMode: EditMode?
    private var renderedSelection: UUID?
    private var renderedPreviewValid: Bool?
    private var lastUpdateTime: TimeInterval?
    private var tickAccumulator: TimeInterval = 0

    /// Pan/pinch state lives in the input extension; stored here because extensions cannot add storage.
    var panMode: PanMode = .none
    var gestureRecognizersInstalled: [UIGestureRecognizer] = []

    var reduceMotion: Bool { UIAccessibility.isReduceMotionEnabled }

    init(store: GameStore) {
        self.store = store
        geometry = GridGeometry(tileSize: Self.tileSize, columns: store.world.width, rows: store.world.height)
        cameraBounds = CameraBounds(mapSize: geometry.mapSize)
        super.init(size: CGSize(width: 390, height: 844))
        scaleMode = .resizeFill
        anchorPoint = .zero
        backgroundColor = IslandArt.Palette.water
        camera = cameraNode
        addChild(cameraNode)
        objectLayer.zPosition = 5
        overlayLayer.zPosition = 20
        gridOverlay.zPosition = 2
        [terrainLayer, gridOverlay, objectLayer, overlayLayer].forEach(addChild)
        objectLayer.addChild(creatureNode)
        buildTerrain()
        syncWithStore(animated: false)
    }

    @available(*, unavailable)
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) is not supported")
    }

    override func didMove(to view: SKView) {
        view.isMultipleTouchEnabled = true
        installGestures(on: view)
        resetCamera()
    }

    override func willMove(from view: SKView) {
        removeGestures(from: view)
    }

    override func didChangeSize(_ oldSize: CGSize) {
        super.didChangeSize(oldSize)
        clampCamera()
    }

    override func update(_ currentTime: TimeInterval) {
        let delta = min(currentTime - (lastUpdateTime ?? currentTime), 1)
        lastUpdateTime = currentTime
        tickAccumulator += delta
        while tickAccumulator >= Self.tickInterval {
            tickAccumulator -= Self.tickInterval
            handle(store.tick())
        }
        syncWithStore(animated: true)
    }

    // MARK: Store → nodes

    /// Cheap per-frame diff: only rebuilds what changed since the last frame.
    func syncWithStore(animated: Bool) {
        if store.objectsRevision != renderedRevision {
            renderedRevision = store.objectsRevision
            syncObjects()
        }
        let world = store.world
        creatureNode.show(world.creature, in: world, geometry: geometry, animated: animated, reduceMotion: reduceMotion)
        let previewValid = store.previewIssue == nil
        if store.mode != renderedMode || previewValid != renderedPreviewValid {
            renderedMode = store.mode
            renderedPreviewValid = previewValid
            syncPreview()
        }
        if store.selectedObjectID != renderedSelection {
            renderedSelection = store.selectedObjectID
            syncSelection()
        }
    }

    private func buildTerrain() {
        let world = store.world
        for y in 0..<world.height {
            for x in 0..<world.width {
                let tile = TileCoord(x: x, y: y)
                guard let terrain = world.terrain(at: tile) else { continue }
                terrainLayer.addChild(IslandArt.terrainTile(terrain, at: tile, size: Self.tileSize))
            }
        }
        let path = CGMutablePath()
        let size = geometry.mapSize
        for column in 0...world.width {
            path.move(to: CGPoint(x: Double(column) * Self.tileSize, y: 0))
            path.addLine(to: CGPoint(x: Double(column) * Self.tileSize, y: size.height))
        }
        for row in 0...world.height {
            path.move(to: CGPoint(x: 0, y: Double(row) * Self.tileSize))
            path.addLine(to: CGPoint(x: size.width, y: Double(row) * Self.tileSize))
        }
        let lines = SKShapeNode(path: path)
        lines.strokeColor = IslandArt.Palette.ink.withAlphaComponent(0.12)
        lines.lineWidth = 1
        gridOverlay.addChild(lines)
        gridOverlay.isHidden = true
    }

    private func syncObjects() {
        let objects = store.world.objects
        let alive = Set(objects.map(\.id))
        for (id, node) in objectNodes where !alive.contains(id) {
            node.removeFromParent()
            objectNodes[id] = nil
        }
        for object in objects {
            let node = objectNodes[object.id] ?? makeObjectNode(object)
            let target = scenePosition(for: object.kind, at: object.origin)
            if node.position != target {
                node.position = target
                if !reduceMotion {
                    node.run(.sequence([.scale(to: 1.08, duration: 0.08), .scale(to: 1, duration: 0.1)]))
                }
            }
            // Lower objects are drawn in front, giving the 3/4 view its depth.
            node.zPosition = CGFloat(store.world.height - object.origin.y)
        }
        syncSelection()
    }

    private func makeObjectNode(_ object: WorldObject) -> SKNode {
        let node = IslandArt.objectNode(object.kind)
        node.name = "object-\(object.kind.rawValue)"
        objectLayer.addChild(node)
        objectNodes[object.id] = node
        return node
    }

    private func scenePosition(for kind: ObjectKind, at origin: TileCoord) -> CGPoint {
        CGPoint(x: Double(origin.x) * Self.tileSize, y: Double(origin.y) * Self.tileSize)
    }

    private func syncPreview() {
        previewNode?.removeFromParent()
        previewNode = nil
        gridOverlay.isHidden = store.mode == .browse
        guard let kind = store.previewKind, let origin = store.previewOrigin else { return }
        let valid = store.previewIssue == nil
        let container = SKNode()
        container.name = "preview"
        container.position = scenePosition(for: kind, at: origin)
        let footprint = CGSize(
            width: Double(kind.footprint.width) * Self.tileSize, height: Double(kind.footprint.height) * Self.tileSize)
        let tint = SKShapeNode(rect: CGRect(origin: .zero, size: footprint), cornerRadius: 4)
        tint.fillColor = (valid ? IslandArt.Palette.valid : IslandArt.Palette.invalid).withAlphaComponent(0.45)
        tint.strokeColor = valid ? IslandArt.Palette.cream : IslandArt.Palette.invalid
        tint.lineWidth = 2
        container.addChild(tint)
        let ghost = IslandArt.objectNode(kind)
        ghost.alpha = 0.7
        container.addChild(ghost)
        // Shape cue in addition to color, for color-blind players: ○ = OK, × = blocked.
        let mark = SKLabelNode(text: valid ? "○" : "×")
        mark.fontName = "HiraginoSans-W6"
        mark.fontSize = 14
        mark.fontColor = valid ? IslandArt.Palette.ink : IslandArt.Palette.invalid
        mark.position = CGPoint(x: footprint.width - 6, y: footprint.height - 2)
        container.addChild(mark)
        overlayLayer.addChild(container)
        previewNode = container
    }

    private func syncSelection() {
        selectionNode?.removeFromParent()
        selectionNode = nil
        guard let object = store.selectedObject else { return }
        let size = CGSize(
            width: Double(object.kind.footprint.width) * Self.tileSize,
            height: Double(object.kind.footprint.height) * Self.tileSize)
        let outline = SKShapeNode(rect: CGRect(origin: .zero, size: size).insetBy(dx: -2, dy: -2), cornerRadius: 5)
        outline.strokeColor = IslandArt.Palette.cream
        outline.lineWidth = 3
        outline.position = scenePosition(for: object.kind, at: object.origin)
        outline.name = "selection"
        if !reduceMotion {
            outline.run(
                .repeatForever(.sequence([.fadeAlpha(to: 0.4, duration: 0.6), .fadeAlpha(to: 1, duration: 0.6)])))
        }
        overlayLayer.addChild(outline)
        selectionNode = outline
    }

    // MARK: Events → effects

    private func handle(_ events: [WorldEvent]) {
        for event in events {
            switch event {
            case .reactionInterrupted:
                creatureNode.flash("?", reduceMotion: reduceMotion)
            case .discovered:
                sparkle(at: creatureNode.position)
            case .creatureMoved, .reactionStarted:
                break
            }
        }
    }

    private func sparkle(at point: CGPoint) {
        guard !reduceMotion else { return }
        for index in 0..<6 {
            let star = IslandArt.px(0, 0, 2, 2, IslandArt.Palette.path)
            star.position = CGPoint(x: point.x, y: point.y + 20)
            star.zPosition = 30
            addChild(star)
            let angle = Double(index) / 6 * 2 * .pi
            let move = SKAction.moveBy(x: cos(angle) * 22, y: sin(angle) * 22, duration: 0.5)
            star.run(.sequence([.group([move, .fadeOut(withDuration: 0.5)]), .removeFromParent()]))
        }
    }
}
