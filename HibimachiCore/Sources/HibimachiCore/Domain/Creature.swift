import Foundation

/// The single wandering creature of P0. Only `id` and `position` are persisted;
/// `activity` and `cooldowns` are transient and reset to idle on load.
public struct Creature: Equatable, Sendable {
    public let id: UUID
    public var position: TileCoord
    public var activity: CreatureActivity
    /// Remaining ticks before a reaction kind may trigger again.
    public var cooldowns: [ReactionKind: Int]

    public init(id: UUID, position: TileCoord, activity: CreatureActivity = .idle(ticksLeft: 2)) {
        self.id = id
        self.position = position
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
