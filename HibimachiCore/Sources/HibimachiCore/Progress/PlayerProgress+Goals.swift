import Foundation

/// Goals and their quests: create, rename, rest, resume; add, edit or retire a quest.
extension PlayerProgress {
    public mutating func addGoal(
        title: String, category: GoalCategory, at date: Date, makeID: () -> UUID,
        language: QuestPresets.Language = .japanese
    ) -> Result<Goal, ProgressError> {
        let trimmed = title.trimmingCharacters(in: .whitespacesAndNewlines)
        if let issue = Self.titleIssue(trimmed, limit: Goal.titleLimit) { return .failure(issue) }
        guard activeGoals.count < Self.activeGoalLimit else {
            return .failure(.tooManyGoals(limit: Self.activeGoalLimit))
        }
        let goal = Goal(id: makeID(), title: trimmed, category: category, createdAt: date)
        goals.append(goal)
        for preset in QuestPresets.quests(for: category, language: language) {
            quests.append(QuestTemplate(id: makeID(), goalID: goal.id, title: preset.title, minutes: preset.minutes))
        }
        return .success(goal)
    }

    public mutating func archiveGoal(_ id: UUID) -> Result<Goal, ProgressError> {
        guard let index = goals.firstIndex(where: { $0.id == id }) else { return .failure(.unknownGoal(id)) }
        goals[index].isArchived = true
        return .success(goals[index])
    }

    public mutating func renameGoal(_ id: UUID, to title: String) -> Result<Goal, ProgressError> {
        guard let index = goals.firstIndex(where: { $0.id == id }) else { return .failure(.unknownGoal(id)) }
        let trimmed = title.trimmingCharacters(in: .whitespacesAndNewlines)
        if let issue = Self.titleIssue(trimmed, limit: Goal.titleLimit) { return .failure(issue) }
        goals[index].title = trimmed
        return .success(goals[index])
    }

    /// Brings a resting goal back, within the active limit.
    public mutating func resumeGoal(_ id: UUID) -> Result<Goal, ProgressError> {
        guard let index = goals.firstIndex(where: { $0.id == id }) else { return .failure(.unknownGoal(id)) }
        guard goals[index].isArchived else { return .success(goals[index]) }
        guard activeGoals.count < Self.activeGoalLimit else {
            return .failure(.tooManyGoals(limit: Self.activeGoalLimit))
        }
        goals[index].isArchived = false
        return .success(goals[index])
    }

    /// Changes a quest's wording or length. Rewards already granted keep their amounts (the ledger is history).
    public mutating func editQuest(_ id: UUID, title: String, minutes: Int) -> Result<QuestTemplate, ProgressError> {
        guard let index = quests.firstIndex(where: { $0.id == id }) else { return .failure(.unknownQuest(id)) }
        let trimmed = title.trimmingCharacters(in: .whitespacesAndNewlines)
        if let issue = Self.titleIssue(trimmed, limit: Goal.titleLimit) { return .failure(issue) }
        guard QuestTemplate.minutesRange.contains(minutes) else { return .failure(.invalidMinutes) }
        quests[index].title = trimmed
        quests[index].minutes = minutes
        return .success(quests[index])
    }

    /// Stops suggesting a quest. One that was never done is deleted; one with history is only retired.
    public mutating func removeQuest(_ id: UUID) -> Result<Void, ProgressError> {
        guard let index = quests.firstIndex(where: { $0.id == id }) else { return .failure(.unknownQuest(id)) }
        if completions.contains(where: { $0.questID == id }) {
            quests[index].isRetired = true
        } else {
            quests.remove(at: index)
        }
        return .success(())
    }

    public mutating func addQuest(
        to goalID: UUID, title: String, minutes: Int, id: UUID
    ) -> Result<QuestTemplate, ProgressError> {
        guard let goal = goals.first(where: { $0.id == goalID }) else { return .failure(.unknownGoal(goalID)) }
        guard !goal.isArchived else { return .failure(.goalArchived(goalID)) }
        let trimmed = title.trimmingCharacters(in: .whitespacesAndNewlines)
        if let issue = Self.titleIssue(trimmed, limit: Goal.titleLimit) { return .failure(issue) }
        guard QuestTemplate.minutesRange.contains(minutes) else { return .failure(.invalidMinutes) }
        let quest = QuestTemplate(id: id, goalID: goalID, title: trimmed, minutes: minutes)
        quests.append(quest)
        return .success(quest)
    }
}
