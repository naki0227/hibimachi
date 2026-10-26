import Foundation

/// Things that happened during a simulation tick. Rendering uses them for emotes/toasts; nothing here grants rewards.
public enum WorldEvent: Equatable, Sendable {
    case creatureMoved(to: TileCoord)
    case reactionStarted(ReactionKind, objectID: UUID)
    /// First time a reaction is seen. Emitted at most once per kind per world.
    case discovered(ReactionKind)
    /// The target disappeared or changed (moved, removed, flower taken away) before/while reacting.
    case reactionInterrupted(ReactionKind)
}
