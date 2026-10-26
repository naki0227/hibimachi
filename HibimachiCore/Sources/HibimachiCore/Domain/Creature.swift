import Foundation

/// A wandering island resident. `id`, `species`, `position` and `friendship` are persisted;
/// `activity` and `cooldowns` are transient and reset to idle on load.
public struct Creature: Equatable, Sendable {
    public let id: UUID
    public let species: Species
    public var position: TileCoord
    public var friendship: Friendship
    public var activity: CreatureActivity
    /// Remaining ticks before a reaction kind may trigger again.
    public var cooldowns: [ReactionKind: Int]

    public init(
        id: UUID, species: Species = .mochi, position: TileCoord, friendship: Friendship = Friendship(),
        activity: CreatureActivity = .idle(ticksLeft: 2)
    ) {
        self.id = id
        self.species = species
        self.position = position
        self.friendship = friendship
        self.activity = activity
        self.cooldowns = [:]
    }
}

/// State machine of the creature (GAME-DESIGN: idle / wander / approach / interact / leave).
public enum CreatureActivity: Equatable, Sendable {
    case idle(ticksLeft: Int)
    case wandering(path: [TileCoord])
    case approaching(ReactionKind, targetID: UUID, path: [TileCoord])
    case interacting(ReactionKind, targetID: UUID, ticksLeft: Int)
    case leaving(path: [TileCoord])

    public var reaction: ReactionKind? {
        switch self {
        case .approaching(let kind, _, _), .interacting(let kind, _, _): kind
        case .idle, .wandering, .leaving: nil
        }
    }

    public var targetID: UUID? {
        switch self {
        case .approaching(_, let id, _), .interacting(_, let id, _): id
        case .idle, .wandering, .leaving: nil
        }
    }
}
