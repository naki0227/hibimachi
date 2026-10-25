import Foundation

/// Result of reading the saved island. Unreadable data is never silently overwritten:
/// implementations move it aside first and report where it went.
public enum WorldLoadOutcome: Equatable, Sendable {
    case notFound
    case loaded(World)
    case unreadable(reason: String, backupFileName: String?)
}

/// Persistence port used by `GameStore`. Implemented in `HibimachiStorage`.
public protocol WorldRepository: Sendable {
    func load() -> WorldLoadOutcome
    func save(_ world: World) throws
}
