import Foundation

/// A goal's tower on one of the islets around the island (ADR-0017), drawn from progress every time.
public struct GoalMonument: Equatable, Sendable {
    public static let maxStage = 4

    public let goalID: UUID
    public let title: String
    public let category: GoalCategory
    public let finishedSteps: Int
    public let totalSteps: Int

    /// 0: only the foundation (no steps yet), 1...3: growing with finished steps, 4: every step done.
    public var stage: Int {
        guard totalSteps > 0 else { return 0 }
        if finishedSteps >= totalSteps { return Self.maxStage }
        return 1 + (Self.maxStage - 1) * finishedSteps / totalSteps
    }

    /// Active goals in the order they were made, at most one per islet.
    public static func all(in progress: PlayerProgress) -> [GoalMonument] {
        progress.activeGoals.sorted { $0.createdAt < $1.createdAt }.prefix(PlayerProgress.activeGoalLimit).map { goal in
            let statuses = progress.stepStatuses(of: goal.id)
            return GoalMonument(
                goalID: goal.id, title: goal.title, category: goal.category,
                finishedSteps: statuses.filter(\.isFinished).count, totalSteps: statuses.count)
        }
    }
}

/// A step just finished, for the "塔が1段のびた" card.
public struct StepFinished: Equatable, Sendable {
    public let goalTitle: String
    public let stepTitle: String
    /// The goal's last step: the tower is complete.
    public let completesGoal: Bool

    public init(goalTitle: String, stepTitle: String, completesGoal: Bool) {
        self.goalTitle = goalTitle
        self.stepTitle = stepTitle
        self.completesGoal = completesGoal
    }
}

/// What the player has been doing lately, by category (ADR-0017). Counts only: it never judges or guesses
/// personality, and with too little activity there is no leaning at all.
public enum IslandMood {
    public static let windowDays = 28
    public static let minimumCompletions = 5
    /// The top category must be at least this share of recent completions.
    public static let minimumShare = 0.4

    public static func leaning(in progress: PlayerProgress, today: LocalDay) -> GoalCategory? {
        let categories = Dictionary(
            progress.goals.map { ($0.id, $0.category) }, uniquingKeysWith: { first, _ in first })
        let recent = progress.completions.filter { completion in
            let age = today.daysSince(completion.day)
            return age >= 0 && age < windowDays
        }
        guard recent.count >= minimumCompletions else { return nil }
        var counts: [GoalCategory: Int] = [:]
        for completion in recent {
            if let category = categories[completion.goalID] { counts[category, default: 0] += 1 }
        }
        // Ties go to the category listed first, so the answer does not flicker.
        guard
            let top = GoalCategory.allCases.max(by: { counts[$0, default: 0] < counts[$1, default: 0] }),
            Double(counts[top, default: 0]) >= Double(recent.count) * minimumShare
        else { return nil }
        return top
    }
}
