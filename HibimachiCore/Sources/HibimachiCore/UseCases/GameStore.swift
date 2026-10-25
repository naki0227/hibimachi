import Foundation
import Observation

public enum EditMode: Equatable, Sendable {
    case browse
    case placing(ObjectKind, origin: TileCoord)
    case moving(UUID, origin: TileCoord)
}

public enum StartupNotice: Equatable, Sendable {
    /// The save file could not be read; it was moved aside and a fresh island was started.
    case recoveredFromUnreadableSave(backupFileName: String?)
}

/// Application state for the island screen: edits, selection, simulation ticks and autosave.
///
/// UI layers (SwiftUI, SpriteKit) only call these methods and read state; all rules live in Domain/Simulation.
/// Order for every edit: validate → update state → save → (UI re-renders from state). A failed save keeps the
/// in-memory island and is retried on the next change or when the app goes to the background.
@MainActor
@Observable
public final class GameStore {
    public private(set) var editor: WorldEditor
    public private(set) var mode: EditMode = .browse
    public private(set) var selectedObjectID: UUID?
    /// Why the last confirm was rejected (shown next to the preview). Cleared when the preview moves.
    public private(set) var lastRejection: PlacementError?
    /// Discoveries waiting to be shown as a toast, oldest first.
    public private(set) var pendingDiscoveries: [ReactionKind] = []
    public private(set) var saveErrorMessage: String?
    public private(set) var startupNotice: StartupNotice?
    /// Bumped whenever the set or position of objects changes, so renderers can diff cheaply.
    public private(set) var objectsRevision = 0

    @ObservationIgnored private let repository: any WorldRepository
    @ObservationIgnored private var rng: SeededRandom
    @ObservationIgnored private let makeID: () -> UUID

    public init(repository: any WorldRepository, seed: UInt64, makeID: @escaping () -> UUID = UUID.init) {
        self.repository = repository
        self.rng = SeededRandom(seed: seed)
        self.makeID = makeID
        switch repository.load() {
        case .loaded(let world):
            editor = WorldEditor(world: world)
        case .notFound:
            editor = WorldEditor(world: IslandFactory.makeWorld(makeID: makeID))
            persist()
        case .unreadable(_, let backup):
            editor = WorldEditor(world: IslandFactory.makeWorld(makeID: makeID))
            startupNotice = .recoveredFromUnreadableSave(backupFileName: backup)
            persist()
        }
    }

    public var world: World { editor.world }
    public var canUndo: Bool { editor.canUndo }
    public var selectedObject: WorldObject? { selectedObjectID.flatMap(world.object(withID:)) }

    // MARK: Preview

    public var previewKind: ObjectKind? {
        switch mode {
        case .browse: nil
        case .placing(let kind, _): kind
        case .moving(let id, _): world.object(withID: id)?.kind
        }
    }

    public var previewOrigin: TileCoord? {
        switch mode {
        case .browse: nil
        case .placing(_, let origin), .moving(_, let origin): origin
        }
    }

    /// `nil` means the preview can be confirmed.
    public var previewIssue: PlacementError? {
        switch mode {
        case .browse: nil
        case .placing(let kind, let origin): world.placementIssue(for: kind, at: origin)
        case .moving(let id, let origin):
            if let object = world.object(withID: id) {
                world.placementIssue(for: object.kind, at: origin, ignoring: id)
            } else {
                .unknownObject(id)
            }
        }
    }

    // MARK: Editing

    public func beginPlacing(_ kind: ObjectKind) {
        selectedObjectID = nil
        lastRejection = nil
        mode = .placing(kind, origin: suggestedOrigin(for: kind))
    }

    public func beginMovingSelection() {
        guard let object = selectedObject else { return }
        lastRejection = nil
        mode = .moving(object.id, origin: object.origin)
    }

    /// Moves the preview; the footprint is kept inside the map so the ghost never disappears off-screen.
    public func setPreviewOrigin(_ origin: TileCoord) {
        guard let kind = previewKind else { return }
        let clamped = TileCoord(
            x: min(max(origin.x, 0), world.width - kind.footprint.width),
            y: min(max(origin.y, 0), world.height - kind.footprint.height)
        )
        lastRejection = nil
        switch mode {
        case .browse: break
        case .placing(let kind, _): mode = .placing(kind, origin: clamped)
        case .moving(let id, _): mode = .moving(id, origin: clamped)
        }
    }

    public func nudgePreview(dx: Int, dy: Int) {
        guard let origin = previewOrigin else { return }
        setPreviewOrigin(origin.offset(dx: dx, dy: dy))
    }

    /// Commits the preview. Returns `false` (and sets `lastRejection`) when the spot is invalid; nothing changes then.
    @discardableResult
    public func confirmPreview() -> Bool {
        let result: Result<WorldObject, PlacementError>
        switch mode {
        case .browse: return false
        case .placing(let kind, let origin): result = editor.place(kind, at: origin, id: makeID())
        case .moving(let id, let origin): result = editor.move(id, to: origin)
        }
        switch result {
        case .success(let object):
            mode = .browse
            selectedObjectID = object.id
            lastRejection = nil
            objectsDidChange()
            return true
        case .failure(let issue):
            lastRejection = issue
            return false
        }
    }

    public func cancelEdit() {
        mode = .browse
        lastRejection = nil
    }

    /// Tap in browse mode: select what is under the finger (or clear the selection).
    public func selectObject(at tile: TileCoord) {
        guard mode == .browse else { return }
        selectedObjectID = world.object(at: tile)?.id
    }

    public func select(_ id: UUID?) {
        guard mode == .browse else { return }
        selectedObjectID = id.flatMap { world.object(withID: $0)?.id }
    }

    public func removeSelection() {
        guard mode == .browse, let id = selectedObjectID else { return }
        if case .success = editor.remove(id) {
            selectedObjectID = nil
            objectsDidChange()
        }
    }

    public func undo() {
        cancelEdit()
        guard editor.undo() else { return }
        if let id = selectedObjectID, world.object(withID: id) == nil { selectedObjectID = nil }
        objectsDidChange()
    }

    /// Starts over with the default island. Discoveries are cleared too; the UI must confirm first.
    public func resetIsland() {
        editor = WorldEditor(world: IslandFactory.makeWorld(makeID: makeID))
        mode = .browse
        selectedObjectID = nil
        pendingDiscoveries = []
        objectsDidChange()
    }

    // MARK: Simulation

    /// Advances the creature by one step. New discoveries are queued for the UI and saved immediately.
    @discardableResult
    public func tick() -> [WorldEvent] {
        let events = CreatureBrain.step(world: &editor.world, rng: &rng)
        let discovered = events.compactMap { event -> ReactionKind? in
            if case .discovered(let kind) = event { return kind }
            return nil
        }
        if !discovered.isEmpty {
            pendingDiscoveries.append(contentsOf: discovered)
            persist()
        }
        return events
    }

    public func dismissDiscovery() {
        if !pendingDiscoveries.isEmpty { pendingDiscoveries.removeFirst() }
    }

    public func dismissStartupNotice() {
        startupNotice = nil
    }

    // MARK: Persistence

    /// Saves the current island. Safe to call repeatedly (e.g. when the app moves to the background).
    public func persist() {
        do {
            try repository.save(world)
            saveErrorMessage = nil
        } catch {
            saveErrorMessage = String(describing: error)
        }
    }

    private func objectsDidChange() {
        objectsRevision += 1
        persist()
    }

    /// First valid spot around the creature, so a new object appears where the player is already looking.
    private func suggestedOrigin(for kind: ObjectKind) -> TileCoord {
        let center = world.creature.position
        for radius in 1...max(world.width, world.height) {
            for dy in -radius...radius {
                for dx in -radius...radius where max(abs(dx), abs(dy)) == radius {
                    let origin = center.offset(dx: dx, dy: dy)
                    if world.placementIssue(for: kind, at: origin) == nil { return origin }
                }
            }
        }
        return TileCoord(x: 0, y: 0)
    }
}
