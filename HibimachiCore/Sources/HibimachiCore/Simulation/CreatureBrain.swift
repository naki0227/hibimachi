import Foundation

/// Advances every resident's state machine by one tick, in order. Pure function of (world, phase, rng):
/// the same seed, edits and time of day always produce the same behaviour.
public enum CreatureBrain {
    static let wanderRadius = 4
    static let wanderWeight = 2
    static let idleTicks = 2...4

    public static func step<R: RandomNumberGenerator>(
        world: inout World, phase: DayPhase = .day, rng: inout R
    ) -> [WorldEvent] {
        var events: [WorldEvent] = []
        for index in world.residents.indices {
            step(residentAt: index, world: &world, phase: phase, rng: &rng, events: &events)
        }
        return events
    }

    private static func step<R: RandomNumberGenerator>(
        residentAt index: Int, world: inout World, phase: DayPhase, rng: inout R, events: inout [WorldEvent]
    ) {
        var creature = world.residents[index]
        let me = creature.id
        creature.cooldowns = creature.cooldowns.compactMapValues { $0 > 1 ? $0 - 1 : nil }

        switch creature.activity {
        case .idle(let ticksLeft):
            creature.activity =
                ticksLeft > 1
                ? .idle(ticksLeft: ticksLeft - 1) : decide(for: creature, in: world, phase: phase, rng: &rng)

        case .wandering(let path):
            creature.activity =
                walk(&creature, along: path, in: world, events: &events).map { .wandering(path: $0) }
                ?? .idle(ticksLeft: Int.random(in: idleTicks, using: &rng))

        case .leaving(let path):
            creature.activity =
                walk(&creature, along: path, in: world, events: &events).map { .leaving(path: $0) }
                ?? .idle(ticksLeft: Int.random(in: idleTicks, using: &rng))

        case .approaching(let kind, let targetID, let path):
            let rule = ReactionRule.rule(for: kind)
            guard let target = world.object(withID: targetID), rule.accepts(target, in: world),
                isInteractionTile(path.last ?? creature.position, for: target)
            else {
                events.append(.reactionInterrupted(kind, by: me))
                creature.activity = .idle(ticksLeft: 2)
                break
            }
            if let remaining = walk(&creature, along: path, in: world, events: &events) {
                creature.activity = .approaching(kind, targetID: targetID, path: remaining)
            } else if isInteractionTile(creature.position, for: target) {
                creature.activity = .interacting(
                    kind, targetID: targetID, ticksLeft: Int.random(in: rule.duration, using: &rng))
                events.append(.reactionStarted(kind, objectID: targetID, by: me))
                if world.recordDiscovery(kind) { events.append(.discovered(kind, by: me)) }
            } else {
                // Path got blocked by a newly placed object: give up quietly and re-decide soon.
                creature.activity = .idle(ticksLeft: 1)
            }

        case .interacting(let kind, let targetID, let ticksLeft):
            let rule = ReactionRule.rule(for: kind)
            guard let target = world.object(withID: targetID), rule.accepts(target, in: world),
                isInteractionTile(creature.position, for: target)
            else {
                events.append(.reactionInterrupted(kind, by: me))
                creature.activity = .idle(ticksLeft: 2)
                break
            }
            if ticksLeft > 1 {
                creature.activity = .interacting(kind, targetID: targetID, ticksLeft: ticksLeft - 1)
            } else {
                creature.cooldowns[kind] = rule.cooldown
                creature.activity =
                    leavePath(for: creature, in: world, rng: &rng).map { .leaving(path: $0) }
                    ?? .idle(ticksLeft: 2)
            }
        }

        world.residents[index] = creature
    }

    /// Tiles from which the creature interacts with `target`: orthogonally adjacent to its footprint.
    static func isInteractionTile(_ tile: TileCoord, for target: WorldObject) -> Bool {
        let footprint = target.tiles
        return !footprint.contains(tile) && tile.neighbors.contains(where: footprint.contains)
    }

    /// Moves one tile along `path`. Returns the remaining path, or `nil` when finished or blocked.
    private static func walk(
        _ creature: inout Creature,
        along path: [TileCoord],
        in world: World,
        events: inout [WorldEvent]
    ) -> [TileCoord]? {
        guard let next = path.first, world.isWalkable(next),
            next.chebyshevDistance(to: creature.position) <= 1
        else { return nil }
        creature.position = next
        events.append(.creatureMoved(creature.id, to: next))
        let remaining = Array(path.dropFirst())
        return remaining.isEmpty ? nil : remaining
    }

    private struct Candidate {
        let kind: ReactionKind?
        let targetID: UUID?
        let path: [TileCoord]
        let weight: Int
    }

    private static func decide<R: RandomNumberGenerator>(
        for creature: Creature,
        in world: World,
        phase: DayPhase,
        rng: inout R
    ) -> CreatureActivity {
        var candidates: [Candidate] = []
        for rule in ReactionRule.all where creature.cooldowns[rule.kind] == nil && rule.canStart(during: phase) {
            for target in world.objects
            where target.distance(from: creature.position) <= ReactionRule.perceptionRadius
                && rule.accepts(target, in: world)
            {
                guard
                    let path = PathFinder.path(
                        in: world, from: creature.position, where: { isInteractionTile($0, for: target) })
                else { continue }
                let weight = rule.weight * creature.species.preference(for: rule.kind)
                candidates.append(Candidate(kind: rule.kind, targetID: target.id, path: path, weight: weight))
            }
        }
        if let wander = wanderPath(for: creature, in: world, rng: &rng) {
            candidates.append(Candidate(kind: nil, targetID: nil, path: wander, weight: wanderWeight))
        }
        guard let choice = pick(candidates, rng: &rng) else { return .idle(ticksLeft: 3) }
        if let kind = choice.kind, let targetID = choice.targetID {
            return .approaching(kind, targetID: targetID, path: choice.path)
        }
        return .wandering(path: choice.path)
    }

    private static func pick<R: RandomNumberGenerator>(_ candidates: [Candidate], rng: inout R) -> Candidate? {
        let total = candidates.reduce(0) { $0 + $1.weight }
        guard total > 0 else { return nil }
        var roll = Int.random(in: 0..<total, using: &rng)
        for candidate in candidates {
            if roll < candidate.weight { return candidate }
            roll -= candidate.weight
        }
        return candidates.last
    }

    private static func wanderPath<R: RandomNumberGenerator>(
        for creature: Creature,
        in world: World,
        rng: inout R
    ) -> [TileCoord]? {
        randomReachablePath(from: creature.position, in: world, distance: 2...wanderRadius, rng: &rng)
    }

    private static func leavePath<R: RandomNumberGenerator>(
        for creature: Creature,
        in world: World,
        rng: inout R
    ) -> [TileCoord]? {
        randomReachablePath(from: creature.position, in: world, distance: 2...3, rng: &rng)
    }

    private static func randomReachablePath<R: RandomNumberGenerator>(
        from start: TileCoord,
        in world: World,
        distance: ClosedRange<Int>,
        rng: inout R
    ) -> [TileCoord]? {
        let r = distance.upperBound
        let options = (-r...r).flatMap { dx in (-r...r).map { dy in start.offset(dx: dx, dy: dy) } }
            .filter { distance.contains($0.chebyshevDistance(to: start)) && world.isWalkable($0) }
        guard let goal = options.randomElement(using: &rng) else { return nil }
        guard let path = PathFinder.path(in: world, from: start, where: { $0 == goal }), !path.isEmpty else {
            return nil
        }
        return path
    }
}
