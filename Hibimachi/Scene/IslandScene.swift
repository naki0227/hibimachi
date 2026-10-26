import HibimachiCore
import SpriteKit
import UIKit

/// Draws `GameStore` state and forwards input to it. No game rules live here:
/// placement checks, reactions and saving are all in HibimachiCore.
@MainActor
final class IslandScene: SKScene {
    /// Real seconds per simulation tick. One creature step per tick.
    static let tickInterval: TimeInterval = 0.45

    let store: GameStore
    let grid: IsoGrid
    let cameraBounds: CameraBounds
    let cameraNode = SKCameraNode()
    let creatureNode = CreatureNode()
    /// Called with a snapshot around the creature shortly after a first-time discovery.
    var onDiscoverySnapshot: (@MainActor (ReactionKind, CGImage) -> Void)?
    /// Manual time-of-day preview; `nil` follows the device clock.
    var dayPhaseOverride: DayPhase? {
        didSet { refreshDayPhase() }
    }
    /// Currently shown lighting; changed by `refreshDayPhase()`.
    var dayPhase: DayPhase = .day
    var dayPhaseApplied = false

    private let terrainNode = SKSpriteNode()
    /// Everything that is part of the island picture (used for discovery snapshots), excluding UI overlays.
    let worldLayer = SKNode()
    let backdropLayer = SKNode()
    private let objectLayer = SKNode()
    private let overlayLayer = SKNode()
    let gridOverlay = SKNode()
    let glowLayer = SKNode()
    let tint = SKSpriteNode(color: .clear, size: CGSize(width: 8_000, height: 8_000))
    private(set) var objectNodes: [UUID: SKSpriteNode] = [:]
    private var previewNode: SKNode?
    private var selectionNode: SKNode?
    /// Cached for ambient water sparkles; refreshed with the terrain texture.
    var waterTiles: [TileCoord] = []

    private var renderedRevision = -1
    private var renderedTerrainRevision = -1
    private var renderedMode: EditMode?
    private var renderedSelection: UUID?
    private var renderedPreviewValid: Bool?
    private var lastUpdateTime: TimeInterval?
    private var tickAccumulator: TimeInterval = 0
    private var ambientAccumulator: TimeInterval = 0
    private var clockAccumulator: TimeInterval = 0
    private var smokeCounter = 0

    /// Pan/pinch state lives in the input extension; stored here because extensions cannot add storage.
    var panMode: PanMode = .none
    var gestureRecognizersInstalled: [UIGestureRecognizer] = []

    var reduceMotion: Bool { UIAccessibility.isReduceMotionEnabled }

    init(store: GameStore) {
        self.store = store
        grid = IsoGrid(columns: store.world.width, rows: store.world.height)
        cameraBounds = CameraBounds(mapSize: grid.mapSize, minScale: 0.6, maxScale: 3.2, margin: 24)
        super.init(size: CGSize(width: 390, height: 844))
        scaleMode = .resizeFill
        anchorPoint = .zero
        backgroundColor = IslandArt.Palette.sea
        camera = cameraNode
        addChild(cameraNode)
        terrainNode.anchorPoint = .zero
        backdropLayer.zPosition = -10
        terrainNode.zPosition = 0
        gridOverlay.zPosition = 1
        objectLayer.zPosition = 10
        tint.zPosition = 800
        glowLayer.zPosition = 850
        overlayLayer.zPosition = 900
        [backdropLayer, terrainNode, objectLayer, glowLayer].forEach(worldLayer.addChild)
        [worldLayer, gridOverlay, overlayLayer].forEach(addChild)
        cameraNode.addChild(tint)
        objectLayer.addChild(creatureNode)
        buildBackdrop()
        buildSeaPattern()
        buildGridOverlay()
        refreshDayPhase()
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
        ambientAccumulator += delta
        if ambientAccumulator >= 0.35 {
            ambientAccumulator = 0
            spawnSparkle()
            smokeCounter += 1
            if smokeCounter.isMultiple(of: 4) { puffSmoke() }
        }
        clockAccumulator += delta
        if clockAccumulator >= 10 {
            clockAccumulator = 0
            refreshDayPhase()
        }
        syncWithStore(animated: true)
    }

    // MARK: Store → nodes

    /// Cheap per-frame diff: only rebuilds what changed since the last frame.
    func syncWithStore(animated: Bool) {
        if store.terrainRevision != renderedTerrainRevision {
            renderedTerrainRevision = store.terrainRevision
            renderTerrain()
        }
        if store.objectsRevision != renderedRevision {
            renderedRevision = store.objectsRevision
            syncObjects()
        }
        let world = store.world
        creatureNode.show(world.creature, in: world, grid: grid, animated: animated, reduceMotion: reduceMotion)
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

    private func renderTerrain() {
        let texture = TerrainArt.texture(for: store.world)
        terrainNode.texture = texture
        terrainNode.size = CGSize(width: grid.mapSize.width, height: grid.mapSize.height)
        waterTiles = (0..<store.world.width).flatMap { x in
            (0..<store.world.height).compactMap { y in
                store.world.terrain(at: TileCoord(x: x, y: y)) == .water ? TileCoord(x: x, y: y) : nil
            }
        }
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
            let target = grid.frontVertex(at: object.origin).cgPoint
            if node.position != target {
                node.position = target
                if !reduceMotion {
                    node.run(.sequence([.scale(to: 1.08, duration: 0.08), .scale(to: 1, duration: 0.1)]))
                }
            }
            node.zPosition = CGFloat(grid.depth(of: object.kind.footprint, at: object.origin)) * 10
        }
        syncSelection()
        applyLights()
    }

    private func makeObjectNode(_ object: WorldObject) -> SKSpriteNode {
        let node = IslandArt.objectNode(object.kind, lit: dayPhase.lightsOn)
        node.name = "object-\(object.kind.rawValue)"
        objectLayer.addChild(node)
        objectNodes[object.id] = node
        return node
    }

    private func footprintShape(_ footprint: Footprint, at origin: TileCoord) -> SKShapeNode {
        var points = [
            grid.point(x: Double(origin.x), y: Double(origin.y)),
            grid.point(x: Double(origin.x + footprint.width), y: Double(origin.y)),
            grid.point(x: Double(origin.x + footprint.width), y: Double(origin.y + footprint.height)),
            grid.point(x: Double(origin.x), y: Double(origin.y + footprint.height)),
        ].map(\.cgPoint)
        points.append(points[0])
        return SKShapeNode(points: &points, count: points.count)
    }

    private func syncPreview() {
        previewNode?.removeFromParent()
        previewNode = nil
        gridOverlay.isHidden = store.mode == .browse
        guard let kind = store.previewKind, let origin = store.previewOrigin else { return }
        let valid = store.previewIssue == nil
        let container = SKNode()
        container.name = "preview"
        let tintShape = footprintShape(kind.footprint, at: origin)
        tintShape.fillColor = (valid ? IslandArt.Palette.valid : IslandArt.Palette.invalid).withAlphaComponent(0.5)
        tintShape.strokeColor = valid ? IslandArt.Palette.cream : IslandArt.Palette.invalid
        tintShape.lineWidth = 3
        container.addChild(tintShape)
        let ghost = IslandArt.objectNode(kind)
        ghost.alpha = 0.75
        ghost.position = grid.frontVertex(at: origin).cgPoint
        container.addChild(ghost)
        // Shape cue in addition to color, for color-blind players: ○ = OK, × = blocked.
        let mark = SKLabelNode(text: valid ? "○" : "×")
        mark.fontName = "HiraginoSans-W6"
        mark.fontSize = 22
        mark.fontColor = valid ? IslandArt.Palette.ink : IslandArt.Palette.invalid
        let back = grid.point(x: Double(origin.x + kind.footprint.width), y: Double(origin.y + kind.footprint.height))
        mark.position = CGPoint(x: back.x, y: back.y + 6)
        container.addChild(mark)
        overlayLayer.addChild(container)
        previewNode = container
    }

    private func syncSelection() {
        selectionNode?.removeFromParent()
        selectionNode = nil
        guard let object = store.selectedObject else { return }
        let outline = footprintShape(object.kind.footprint, at: object.origin)
        outline.strokeColor = IslandArt.Palette.cream
        outline.fillColor = IslandArt.Palette.cream.withAlphaComponent(0.15)
        outline.lineWidth = 3
        outline.name = "selection"
        if !reduceMotion {
            outline.run(
                .repeatForever(.sequence([.fadeAlpha(to: 0.4, duration: 0.6), .fadeAlpha(to: 1, duration: 0.6)])))
        }
        overlayLayer.addChild(outline)
        selectionNode = outline
    }
}
