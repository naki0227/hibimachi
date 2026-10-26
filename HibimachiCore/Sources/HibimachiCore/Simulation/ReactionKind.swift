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
    // v1.0 additions (2026-10-26).
    /// Looks up at the cherry blossoms.
    case sakuraViewing = "sakura-viewing"
    /// Swings back and forth.
    case swingPlay = "swing-play"
    /// Warms up by the campfire.
    case campfireWarm = "campfire-warm"
    /// Looks after the vegetable garden.
    case gardenTend = "garden-tend"
    /// Splashes at the fountain.
    case fountainSplash = "fountain-splash"
    /// Visits the café.
    case cafeVisit = "cafe-visit"
    /// Sits at a bench in front of the café — a combination.
    case cafeTerrace = "cafe-terrace"
    /// Has a picnic on a mat in the shade of a tree — a combination.
    case picnic = "picnic"
    /// Watches birds at a birdhouse hung near a tree — a combination.
    case birdWatch = "bird-watch"
    /// Waits for a letter at the mailbox.
    case mailWait = "mail-wait"
    /// Peeks into the well.
    case wellPeek = "well-peek"
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
        ReactionRule(
            kind: .sakuraViewing, targetKinds: [.sakuraTree], weight: 3, duration: 10...14, cooldown: 45,
            condition: { _, _ in true }),
        ReactionRule(
            kind: .swingPlay, targetKinds: [.swing], weight: 3, duration: 8...12, cooldown: 40,
            condition: { _, _ in true }),
        ReactionRule(
            kind: .campfireWarm, targetKinds: [.campfire], weight: 3, duration: 12...16, cooldown: 50,
            condition: { _, _ in true }),
        ReactionRule(
            kind: .gardenTend, targetKinds: [.garden], weight: 2, duration: 10...14, cooldown: 45,
            condition: { _, _ in true }),
        ReactionRule(
            kind: .fountainSplash, targetKinds: [.fountain], weight: 3, duration: 8...12, cooldown: 40,
            condition: { _, _ in true }),
        ReactionRule(
            kind: .cafeVisit, targetKinds: [.cafe], weight: 2, duration: 10...14, cooldown: 45,
            condition: { cafe, world in !has(.bench, near: cafe, in: world) }),
        ReactionRule(
            kind: .cafeTerrace, targetKinds: [.cafe], weight: 4, duration: 12...16, cooldown: 45,
            condition: { cafe, world in has(.bench, near: cafe, in: world) }),
        ReactionRule(
            kind: .picnic, targetKinds: [.picnicMat], weight: 4, duration: 12...16, cooldown: 50,
            condition: { mat, world in hasTree(near: mat, in: world) }),
        ReactionRule(
            kind: .birdWatch, targetKinds: [.birdhouse], weight: 3, duration: 10...14, cooldown: 45,
            condition: { birdhouse, world in hasTree(near: birdhouse, in: world) }),
        ReactionRule(
            kind: .mailWait, targetKinds: [.mailbox], weight: 2, duration: 8...12, cooldown: 60,
            condition: { _, _ in true }),
        ReactionRule(
            kind: .wellPeek, targetKinds: [.well], weight: 2, duration: 8...12, cooldown: 45,
            condition: { _, _ in true }),
    ]

    public static func rule(for kind: ReactionKind) -> ReactionRule {
        // `all` covers every case; the test suite asserts this.
        all.first { $0.kind == kind } ?? all[0]
    }

    static func hasFlower(near object: WorldObject, in world: World) -> Bool {
        has(.flower, near: object, in: world)
    }

    /// Another object of `kind` touching `object`'s footprint (also diagonally).
    static func has(_ kind: ObjectKind, near object: WorldObject, in world: World) -> Bool {
        world.objects.contains { other in
            other.kind == kind && other.tiles.contains { object.distance(from: $0) == 1 }
        }
    }

    static func hasTree(near object: WorldObject, in world: World) -> Bool {
        world.objects.contains { other in
            other.kind.isTree && other.tiles.contains { object.distance(from: $0) == 1 }
        }
    }
}
