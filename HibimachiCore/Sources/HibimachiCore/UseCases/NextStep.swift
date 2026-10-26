import Foundation

/// A gentle "what next" shown after finishing a quest (GAME-DESIGN P1: quietly suggest a new building or a
/// discovery). Never a demand: it only points at something the player can do or will soon unlock.
public enum NextStep: Equatable, Sendable {
    /// Unlocked, affordable now, not on the island yet, and some resident would react to it.
    case canBuild(ObjectKind)
    /// A reaction not seen yet whose object is already on the island (often a combination hint).
    case tryReaction(ReactionKind)
    /// The next locked kind and what opens it.
    case unlocksSoon(ObjectKind, Unlocks.Requirement)

    /// Picks one suggestion. `variety` (e.g. the number of completions) rotates between equal options so
    /// the hint is not always the same.
    public static func suggestion(world: World, progress: PlayerProgress, variety: Int = 0) -> NextStep? {
        let level = progress.level
        let discoveries = world.discoveries.count
        let onIsland = Set(world.objects.map(\.kind))
        let undiscovered = ReactionKind.allCases.filter { !world.discoveries.contains($0) }

        let buildable = ObjectKind.allCases.filter { kind in
            !onIsland.contains(kind)
                && Unlocks.isUnlocked(kind, level: level, discoveries: discoveries)
                && (progress.available(kind, in: world) > 0 || progress.sparkles >= RewardRule.price(of: kind))
                && undiscovered.contains { ReactionRule.rule(for: $0).targetKinds.contains(kind) }
        }
        if !buildable.isEmpty { return .canBuild(buildable[variety % buildable.count]) }

        let reachable = undiscovered.filter { !ReactionRule.rule(for: $0).targetKinds.isDisjoint(with: onIsland) }
        if !reachable.isEmpty { return .tryReaction(reachable[variety % reachable.count]) }

        let locked = ObjectKind.allCases
            .filter { !Unlocks.isUnlocked($0, level: level, discoveries: discoveries) }
            .sorted { Unlocks.requirement(for: $0).level < Unlocks.requirement(for: $1).level }
        return locked.first.map { .unlocksSoon($0, Unlocks.requirement(for: $0)) }
    }
}

extension GameStore {
    /// Suggestion for the reward banner; changes as quests are completed.
    public var nextStep: NextStep? {
        NextStep.suggestion(world: world, progress: progress, variety: progress.completions.count)
    }

    /// Local day an object was placed by the player, if known.
    public func placedDay(of object: WorldObject) -> LocalDay? {
        object.placedAt.map { LocalDay(date: $0, calendar: calendar) }
    }
}
