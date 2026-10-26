import Foundation

/// Rule-based "today's quests" (no AI). Deterministic per day so the list does not reshuffle while open.
public enum DailyPlanner {
    public static let dailyCount = 3

    /// Up to `dailyCount` quests, taking turns between active goals, skipping today's completed/skipped ones.
    public static func suggestions(for day: LocalDay, in progress: PlayerProgress) -> [QuestTemplate] {
        var rng = SeededRandom(seed: day.seed)
        let goals = progress.activeGoals.sorted { $0.createdAt < $1.createdAt }
        var pools: [[QuestTemplate]] = goals.map { goal in
            progress.quests(of: goal.id)
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
