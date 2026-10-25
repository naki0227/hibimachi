import Foundation

/// Observable creature reactions to placed objects. Raw values are stable IDs (saves, field guide).
public enum ReactionKind: String, CaseIterable, Sendable {
    /// Rests on a bench that has no flowers nearby.
    case benchRest = "bench-rest"
    /// Rests on a bench with a flower next to it — a combination players can discover.
    case bloomBench = "bloom-bench"
    /// Naps in the shade of a tree.
    case treeNap = "tree-nap"
    /// Comes to look at a pond.
    case pondVisit = "pond-visit"
}

/// Tunable parameters of one reaction. Values are provisional (docs/GAME-DESIGN.md) and in simulation ticks.
public struct ReactionRule: Sendable {
    public let kind: ReactionKind
    public let targetKinds: Set<ObjectKind>
    public let weight: Int
    public let duration: ClosedRange<Int>
    public let cooldown: Int
    /// Extra placement condition beyond the target kind (e.g. "a flower is next to the bench").
    let condition: @Sendable (WorldObject, World) -> Bool

    public func accepts(_ object: WorldObject, in world: World) -> Bool {
        targetKinds.contains(object.kind) && condition(object, world)
    }
}

extension ReactionRule {
    /// How far (in tiles) the creature notices objects.
    public static let perceptionRadius = 5

    public static let all: [ReactionRule] = [
        ReactionRule(
            kind: .benchRest, targetKinds: [.bench], weight: 3, duration: 8...12, cooldown: 40,
            condition: { bench, world in !hasFlower(near: bench, in: world) }),
        ReactionRule(
            kind: .bloomBench, targetKinds: [.bench], weight: 5, duration: 10...14, cooldown: 40,
            condition: { bench, world in hasFlower(near: bench, in: world) }),
        ReactionRule(
            kind: .treeNap, targetKinds: [.roundTree, .pineTree], weight: 2, duration: 12...18, cooldown: 50,
            condition: { _, _ in true }),
        ReactionRule(
            kind: .pondVisit, targetKinds: [.pond], weight: 2, duration: 8...12, cooldown: 45,
            condition: { _, _ in true }),
    ]

    public static func rule(for kind: ReactionKind) -> ReactionRule {
        // `all` covers every case; the test suite asserts this.
        all.first { $0.kind == kind } ?? all[0]
    }

    static func hasFlower(near object: WorldObject, in world: World) -> Bool {
        world.objects.contains { $0.kind == .flower && object.distance(from: $0.origin) == 1 }
    }
}
