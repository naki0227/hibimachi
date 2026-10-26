import Foundation

/// Everything that is saved: the island and the life-side progress.
public struct GameSnapshot: Equatable, Sendable {
    public var world: World
    public var progress: PlayerProgress

    /// Keeps the two halves consistent (owned buildings always cover the placed ones).
    public init(world: World, progress: PlayerProgress) {
        self.world = world
        var progress = progress
        progress.reconcileOwnership(with: world)
        self.progress = progress
    }
}

/// Result of reading the saved game. Unreadable data is never silently overwritten:
/// implementations move it aside first and report where it went.
public enum WorldLoadOutcome: Equatable, Sendable {
    case notFound
    case loaded(GameSnapshot)
    case unreadable(reason: String, backupFileName: String?)
}

/// Persistence port used by `GameStore`. Implemented in `HibimachiStorage`.
public protocol WorldRepository: Sendable {
    func load() -> WorldLoadOutcome
    func save(_ snapshot: GameSnapshot) throws
}
