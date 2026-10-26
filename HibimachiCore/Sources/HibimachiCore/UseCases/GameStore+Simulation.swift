import Foundation

/// Simulation ticks: residents act, discoveries and newcomers queue up for the UI.
extension GameStore {
    /// Advances the residents by one step. New discoveries and newcomers are queued for the UI and saved.
    @discardableResult
    public func tick() -> [WorldEvent] {
        var events = CreatureBrain.step(world: &editor.world, phase: dayPhase, rng: &rng)
        var discovered: [ReactionKind] = []
        for case .discovered(let kind, let who) in events {
            discovered.append(kind)
            _ = creditDiscovery(by: who)
        }
        let arrived = editor.world.welcomeResidentsIfDue(makeID: makeID)
        events += arrived.map { .residentArrived($0.species, id: $0.id) }
        pendingDiscoveries.append(contentsOf: discovered)
        pendingArrivals.append(contentsOf: arrived.map(\.species))
        if !discovered.isEmpty || !arrived.isEmpty { persist() }
        return events
    }

    public func dismissArrival() {
        if !pendingArrivals.isEmpty { pendingArrivals.removeFirst() }
    }

    public func dismissDiscovery() {
        if !pendingDiscoveries.isEmpty { pendingDiscoveries.removeFirst() }
    }

    public func dismissStartupNotice() {
        startupNotice = nil
    }
}
