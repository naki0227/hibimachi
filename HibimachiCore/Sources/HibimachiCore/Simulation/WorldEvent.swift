import Foundation

/// Things that happened during a simulation tick, each tagged with the resident it concerns.
/// Rendering uses them for emotes/toasts; nothing here grants rewards.
public enum WorldEvent: Equatable, Sendable {
    case creatureMoved(UUID, to: TileCoord)
    case reactionStarted(ReactionKind, objectID: UUID, by: UUID)
    /// First time a reaction is seen on this island. Emitted at most once per kind per world.
    case discovered(ReactionKind, by: UUID)
    /// The target disappeared or changed (moved, removed, flower taken away) before/while reacting.
    case reactionInterrupted(ReactionKind, by: UUID)
    /// A new resident moved in because the island got livelier.
    case residentArrived(Species, id: UUID)
}
