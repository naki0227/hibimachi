import Foundation

/// The island grows with the player (ADR-0014): checked whenever progress or discoveries change, and at launch.
extension GameStore {
    /// The next growth's requirement, or `nil` when fully grown (for hints).
    public var nextGrowth: Unlocks.Requirement? { IslandGrowth.nextStage(after: world.growthStage) }

    /// Grows the island for every stage earned but not yet applied. Returns whether it grew; the caller saves.
    @discardableResult
    func growIslandIfDue() -> Bool {
        let earned = IslandGrowth.earnedStages(level: progress.level, discoveries: world.discoveries.count)
        guard world.growthStage < earned else { return false }
        while world.growthStage < earned {
            editor.grow()
            pendingGrowths += 1
        }
        terrainRevision += 1
        return true
    }

    public func dismissGrowth() {
        if pendingGrowths > 0 { pendingGrowths -= 1 }
    }
}
