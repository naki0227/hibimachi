import Foundation

/// Rule-based "today's quests" (no AI). Deterministic per day so the list does not reshuffle while open.
public enum DailyPlanner {
    public static let dailyCount = 3

    /// Up to `dailyCount` quests, taking turns between active goals, skipping today's completed/skipped ones.
    /// A goal with steps offers its everyday quests and its current step's (ADR-0016).
    public static func suggestions(for day: LocalDay, in progress: PlayerProgress) -> [QuestTemplate] {
        var rng = SeededRandom(seed: day.seed)
        let ordered = progress.activeGoals.sorted { $0.createdAt < $1.createdAt }
        // The first goal changes from day to day, so with more goals than daily quests none is always left out.
        let shift = ordered.isEmpty ? 0 : Int(day.seed % UInt64(ordered.count))
        let goals = Array(ordered[shift...] + ordered[..<shift])
        var pools: [[QuestTemplate]] = goals.map { goal in
            progress.suggestableQuests(of: goal.id)
                .filter { !progress.isCompleted($0.id, on: day) && !progress.isSkipped($0.id, on: day) }
                .shuffled(using: &rng)
        }
        var picked: [QuestTemplate] = []
        while picked.count < dailyCount, pools.contains(where: { !$0.isEmpty }) {
            for index in pools.indices where picked.count < dailyCount && !pools[index].isEmpty {
                picked.append(pools[index].removeFirst())
            }
        }
        return picked
    }
}
