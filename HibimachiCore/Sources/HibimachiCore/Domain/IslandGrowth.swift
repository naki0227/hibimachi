import Foundation

/// The island grows as the player does: twice, by level or by discoveries (like `Unlocks`), each time moving the
/// coast out by one ring. The map is sized so both rings fit with sea to spare (ADR-0014).
public enum IslandGrowth {
    /// Side of the square map. Islands start at the 16x16 layout in the middle.
    public static let mapSize = 20

    public static let stages: [Unlocks.Requirement] = [
        Unlocks.Requirement(level: 3, discoveries: 6),
        Unlocks.Requirement(level: 5, discoveries: 12),
    ]

    /// How many growth stages the player has earned.
    public static func earnedStages(level: Int, discoveries: Int) -> Int {
        stages.filter { level >= $0.level || discoveries >= $0.discoveries }.count
    }

    /// The next stage's requirement, or `nil` when the island is fully grown.
    public static func nextStage(after stage: Int) -> Unlocks.Requirement? {
        stage < stages.count ? stages[stage] : nil
    }
}
