/// When each kind becomes available. A kind unlocks at a player level **or** after a number of discoveries
/// on the island, so players who never use quests still reach every building (PRD: no lock-out by activity).
public enum Unlocks {
    public struct Requirement: Equatable, Sendable {
        public let level: Int
        public let discoveries: Int

        public static let always = Requirement(level: 1, discoveries: 0)
    }

    public static func requirement(for kind: ObjectKind) -> Requirement {
        switch kind {
        case .roundTree, .pineTree, .house, .bench, .flower, .pond, .lamp, .bush, .rock, .fence: .always
        case .sakuraTree, .mailbox, .picnicMat, .birdhouse: Requirement(level: 2, discoveries: 3)
        case .swing, .campfire, .well, .garden: Requirement(level: 3, discoveries: 6)
        case .fountain, .cafe: Requirement(level: 4, discoveries: 9)
        }
    }

    public static func isUnlocked(_ kind: ObjectKind, level: Int, discoveries: Int) -> Bool {
        let requirement = requirement(for: kind)
        return level >= requirement.level || discoveries >= requirement.discoveries
    }
}
