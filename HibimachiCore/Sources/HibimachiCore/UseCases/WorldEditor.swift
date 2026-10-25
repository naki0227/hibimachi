import Foundation

/// Place / move / remove with a bounded undo history.
///
/// Undo restores **objects only**: discoveries are never taken back and the creature is not teleported
/// (it only hops aside if a restored object lands on it). Undo history is in-memory and is cleared on relaunch.
public struct WorldEditor: Sendable {
    public static let undoLimit = 20

    /// Simulation code may mutate the creature/discoveries directly; object edits must go through the methods below.
    public var world: World
    private var undoStack: [[WorldObject]] = []

    public init(world: World) {
        self.world = world
    }

    public var canUndo: Bool { !undoStack.isEmpty }

    @discardableResult
    public mutating func place(_ kind: ObjectKind, at origin: TileCoord, id: UUID) -> Result<
        WorldObject, PlacementError
    > {
        recordingUndo { $0.place(kind, at: origin, id: id) }
    }

    @discardableResult
    public mutating func move(_ id: UUID, to origin: TileCoord) -> Result<WorldObject, PlacementError> {
        if world.object(withID: id)?.origin == origin, let object = world.object(withID: id) {
            return .success(object)  // No-op moves should not fill the undo history.
        }
        return recordingUndo { $0.moveObject(id, to: origin) }
    }

    @discardableResult
    public mutating func remove(_ id: UUID) -> Result<WorldObject, PlacementError> {
        recordingUndo { $0.removeObject(id) }
    }

    /// Returns `false` when there is nothing to undo.
    @discardableResult
    public mutating func undo() -> Bool {
        guard let snapshot = undoStack.popLast() else { return false }
        world.restoreObjects(snapshot)
        return true
    }

    private mutating func recordingUndo(
        _ edit: (inout World) -> Result<WorldObject, PlacementError>
    ) -> Result<WorldObject, PlacementError> {
        let before = world.objects
        let result = edit(&world)
        if case .success = result {
            undoStack.append(before)
            if undoStack.count > Self.undoLimit { undoStack.removeFirst() }
        }
        return result
    }
}
