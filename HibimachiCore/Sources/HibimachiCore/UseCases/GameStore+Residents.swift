import Foundation

/// What happened when the player petted a resident.
public enum PetOutcome: Equatable, Sendable {
    /// It counted toward friendship; `leveledUp` when it reached a new level.
    case counted(Friendship.Level, leveledUp: Bool)
    /// Today's pets are used up; the resident is still happy to see you.
    case notCounted(Friendship.Level)
    case unknownResident
}

/// A resident who became closer to the player, for the "なかよしになった" card.
public struct FriendshipNotice: Equatable, Sendable {
    public let species: Species
    public let level: Friendship.Level
}

/// Residents and the player: petting and friendship (2026-10-26).
extension GameStore {
    @discardableResult
    public func pet(_ residentID: UUID) -> PetOutcome {
        guard let index = world.residents.firstIndex(where: { $0.id == residentID }) else { return .unknownResident }
        let before = world.residents[index].friendship.level
        let counted = editor.world.residents[index].friendship.pet(on: today)
        let after = world.residents[index].friendship.level
        guard counted else { return .notCounted(after) }
        noteFriendship(of: index, from: before)
        persist()
        return .counted(after, leveledUp: after > before)
    }

    public func dismissFriendship() {
        if !pendingFriendships.isEmpty { pendingFriendships.removeFirst() }
    }

    /// Credits a discovery to the resident who made it. Returns whether anything changed.
    func creditDiscovery(by residentID: UUID) -> Bool {
        guard let index = world.residents.firstIndex(where: { $0.id == residentID }) else { return false }
        let before = world.residents[index].friendship.level
        editor.world.residents[index].friendship.addDiscovery()
        noteFriendship(of: index, from: before)
        return true
    }

    private func noteFriendship(of index: Int, from before: Friendship.Level) {
        let resident = world.residents[index]
        if resident.friendship.level > before {
            pendingFriendships.append(FriendshipNotice(species: resident.species, level: resident.friendship.level))
        }
    }
}
