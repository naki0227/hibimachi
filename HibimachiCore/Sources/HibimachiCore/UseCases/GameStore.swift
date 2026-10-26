import Foundation
import Observation

public enum EditMode: Equatable, Sendable {
    case browse
    case placing(ObjectKind, origin: TileCoord)
    case moving(UUID, origin: TileCoord)
    /// Tapping tiles switches grass <-> path until the player is done.
    case paintingPath
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
    public internal(set) var editor: WorldEditor
    public private(set) var mode: EditMode = .browse
    public private(set) var selectedObjectID: UUID?
    /// Why the last confirm was rejected (shown next to the preview). Cleared when the preview moves.
    public private(set) var lastRejection: PlacementError?
    /// Discoveries waiting to be shown as a toast, oldest first.
    public internal(set) var pendingDiscoveries: [ReactionKind] = []
    /// Newcomers waiting to be announced ("新しい住人がやってきた").
    public internal(set) var pendingArrivals: [Species] = []
    /// Island growths not yet announced ("島が広がった").
    public internal(set) var pendingGrowths = 0
    /// Residents who just became closer ("なかよしになった"), oldest first.
    public internal(set) var pendingFriendships: [FriendshipNotice] = []
    public private(set) var saveErrorMessage: String?
    public internal(set) var startupNotice: StartupNotice?
    /// Bumped whenever the set or position of objects changes, so renderers can diff cheaply.
    public private(set) var objectsRevision = 0
    /// Bumped whenever terrain changes (path painting, undo, reset).
    public internal(set) var terrainRevision = 0
    /// Goals, quests, rewards and owned buildings (P1).
    public internal(set) var progress: PlayerProgress
    /// The last quest completion, so the UI can offer "取り消す" for a mis-tap.
    public internal(set) var lastCompletion: (completionID: UUID, reward: RewardTransaction)?
    /// Why the last goal/quest/purchase action was refused (shown in the quest sheet).
    public internal(set) var lastProgressError: ProgressError?
    /// Optional memories (P2) and why the last album action was refused.
    public internal(set) var album = Album()
    public internal(set) var lastAlbumError: AlbumError?
    /// The time of day the island shows; some reactions only start then. Set by the app (clock or preview).
    public var dayPhase: DayPhase = .day

    @ObservationIgnored let repository: any WorldRepository
    @ObservationIgnored var rng: SeededRandom
    @ObservationIgnored let makeID: () -> UUID
    @ObservationIgnored let now: () -> Date
    @ObservationIgnored let calendar: Calendar
    /// Where photos go; `nil` means text-only memories (e.g. tests, or a store without a media folder).
    @ObservationIgnored let media: (any MediaStore)?

    public init(
        repository: any WorldRepository,
        seed: UInt64,
        makeID: @escaping () -> UUID = UUID.init,
        now: @escaping () -> Date = Date.init,
        calendar: Calendar = .current,
        media: (any MediaStore)? = nil
    ) {
        self.repository = repository
        self.media = media
        self.rng = SeededRandom(seed: seed)
        self.makeID = makeID
        self.now = now
        self.calendar = calendar
        switch repository.load() {
        case .loaded(let snapshot):
            editor = WorldEditor(world: snapshot.world)
            progress = snapshot.progress
            album = snapshot.album
        case .notFound:
            let world = IslandFactory.makeWorld(makeID: makeID)
            editor = WorldEditor(world: world)
            progress = PlayerProgress.starting(for: world, at: now(), id: makeID())
            persist()
        case .unreadable(_, let backup):
            let world = IslandFactory.makeWorld(makeID: makeID)
            editor = WorldEditor(world: world)
            progress = PlayerProgress.starting(for: world, at: now(), id: makeID())
            startupNotice = .recoveredFromUnreadableSave(backupFileName: backup)
            persist()
        }
        if growIslandIfDue() { persist() }
    }

    public var today: LocalDay { LocalDay(date: now(), calendar: calendar) }

    public var world: World { editor.world }
    public var canUndo: Bool { editor.canUndo }
    public var selectedObject: WorldObject? { selectedObjectID.flatMap(world.object(withID:)) }

    // MARK: Editing

    /// Owned copies of `kind` not yet on the island.
    public func available(_ kind: ObjectKind) -> Int { progress.available(kind, in: world) }

    /// Unlocked by level or by discoveries (see `Unlocks`). Owned copies can always be placed again.
    public func isUnlocked(_ kind: ObjectKind) -> Bool {
        Unlocks.isUnlocked(kind, level: progress.level, discoveries: world.discoveries.count)
    }

    /// A kind can be placed from storage, or bought on confirm if it is unlocked and there are enough きらめき.
    public func canPlaceOrBuy(_ kind: ObjectKind) -> Bool {
        available(kind) > 0 || (isUnlocked(kind) && progress.sparkles >= RewardRule.price(of: kind))
    }

    /// Returns `false` (and does nothing) when the kind is neither in storage nor affordable.
    @discardableResult
    public func beginPlacing(_ kind: ObjectKind) -> Bool {
        guard canPlaceOrBuy(kind) else { return false }
        selectedObjectID = nil
        lastRejection = nil
        mode = .placing(kind, origin: suggestedOrigin(for: kind))
        return true
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
        case .browse, .paintingPath: break
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
        case .browse, .paintingPath: return false
        case .placing(let kind, let origin):
            // Validate the spot before spending anything; buy only when storage is empty.
            if let issue = world.placementIssue(for: kind, at: origin) {
                lastRejection = issue
                return false
            }
            if available(kind) == 0 {
                guard isUnlocked(kind),
                    case .success = progress.purchase(kind, at: now(), transactionID: makeID())
                else { return false }
            }
            result = editor.place(kind, at: origin, id: makeID(), placedAt: now())
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

    public func beginPaintingPath() {
        selectedObjectID = nil
        lastRejection = nil
        mode = .paintingPath
    }

    /// In path mode, switches the tapped tile between grass and path (each tap is one undo step).
    @discardableResult
    public func togglePath(at tile: TileCoord) -> Bool {
        guard mode == .paintingPath else { return false }
        switch editor.togglePath(at: tile) {
        case .success:
            lastRejection = nil
            terrainRevision += 1
            persist()
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

    /// Undo leaves path-painting mode active so several strokes can be undone in a row.
    public func undo() {
        if mode != .paintingPath { cancelEdit() }
        guard editor.undo() else { return }
        if let id = selectedObjectID, world.object(withID: id) == nil { selectedObjectID = nil }
        terrainRevision += 1
        objectsDidChange()
    }

    /// Starts over with the default island. Discoveries are cleared too; the UI must confirm first.
    /// Goals, rewards and owned buildings are kept: nothing earned is lost.
    public func resetIsland() {
        editor = WorldEditor(world: IslandFactory.makeWorld(makeID: makeID))
        progress = GameSnapshot(world: editor.world, progress: progress).progress
        mode = .browse
        selectedObjectID = nil
        pendingDiscoveries = []
        pendingArrivals = []
        pendingFriendships = []
        // Growth was earned by the player, not the island: a fresh island starts at the size already earned.
        growIslandIfDue()
        pendingGrowths = 0
        terrainRevision += 1
        objectsDidChange()
    }

    // MARK: Persistence

    /// Saves the current island. Safe to call repeatedly (e.g. when the app moves to the background).
    public func persist() {
        do {
            try repository.save(GameSnapshot(world: world, progress: progress, album: album))
            saveErrorMessage = nil
        } catch {
            saveErrorMessage = String(describing: error)
        }
    }

    private func objectsDidChange() {
        objectsRevision += 1
        persist()
    }
}
