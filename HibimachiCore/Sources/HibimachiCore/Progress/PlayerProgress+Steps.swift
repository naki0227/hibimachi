import Foundation

/// Goal steps (ADR-0016): a goal broken into ordered steps, each with its own quests. Where a goal stands is
/// counted from completions every time, so undoing a completion also moves its step back.
extension PlayerProgress {
    public func steps(of goalID: UUID) -> [GoalStep] { steps.filter { $0.goalID == goalID } }

    /// Every step of the goal with its count; the first unfinished one is current.
    public func stepStatuses(of goalID: UUID) -> [StepStatus] {
        var foundCurrent = false
        return steps(of: goalID).map { step in
            let questIDs = Set(quests.filter { $0.stepID == step.id }.map(\.id))
            let done = completions.filter { questIDs.contains($0.questID) }.count
            let isCurrent = !foundCurrent && done < step.target
            if isCurrent { foundCurrent = true }
            return StepStatus(step: step, done: done, isCurrent: isCurrent)
        }
    }

    public func currentStep(of goalID: UUID) -> GoalStep? {
        stepStatuses(of: goalID).first(where: \.isCurrent)?.step
    }

    /// Every step finished (`false` for a goal without steps).
    public func isPlanFinished(_ goalID: UUID) -> Bool {
        let statuses = stepStatuses(of: goalID)
        return !statuses.isEmpty && statuses.allSatisfy(\.isFinished)
    }

    /// Quests that can be suggested today for a goal: its everyday quests and those of the current step.
    public func suggestableQuests(of goalID: UUID) -> [QuestTemplate] {
        let current = currentStep(of: goalID)?.id
        return activeQuests(of: goalID).filter { $0.stepID == nil || $0.stepID == current }
    }

    /// Turns an accepted draft into steps and quests. Replaces earlier steps: their quests are retired when they
    /// have history and removed otherwise. Validates everything before changing anything.
    @discardableResult
    public mutating func applyPlan(
        _ draft: PlanDraft, to goalID: UUID, makeID: () -> UUID
    ) -> Result<[GoalStep], ProgressError> {
        guard let goal = goals.first(where: { $0.id == goalID }) else { return .failure(.unknownGoal(goalID)) }
        guard !goal.isArchived else { return .failure(.goalArchived(goalID)) }
        guard PlanDraft.stepCount.contains(draft.steps.count) else { return .failure(.invalidPlan) }
        for step in draft.steps {
            if let issue = Self.titleIssue(step.title.trimmed, limit: Goal.titleLimit) { return .failure(issue) }
            guard GoalStep.targetRange.contains(step.target), PlanDraft.questsPerStep.contains(step.quests.count)
            else { return .failure(.invalidPlan) }
            for quest in step.quests {
                if let issue = Self.titleIssue(quest.title.trimmed, limit: Goal.titleLimit) { return .failure(issue) }
                guard QuestTemplate.minutesRange.contains(quest.minutes) else { return .failure(.invalidMinutes) }
            }
        }
        let oldStepIDs = Set(steps(of: goalID).map(\.id))
        let usedQuests = Set(completions.map(\.questID))
        quests = quests.compactMap { quest in
            guard let stepID = quest.stepID, oldStepIDs.contains(stepID) else { return quest }
            guard usedQuests.contains(quest.id) else { return nil }
            var retired = quest
            retired.isRetired = true
            retired.stepID = nil
            return retired
        }
        steps.removeAll { oldStepIDs.contains($0.id) }
        var added: [GoalStep] = []
        for draftStep in draft.steps {
            let step = GoalStep(id: makeID(), goalID: goalID, title: draftStep.title.trimmed, target: draftStep.target)
            steps.append(step)
            added.append(step)
            for quest in draftStep.quests {
                quests.append(
                    QuestTemplate(
                        id: makeID(), goalID: goalID, title: quest.title.trimmed, minutes: quest.minutes,
                        stepID: step.id))
            }
        }
        return .success(added)
    }

    func validateSteps() throws(ProgressError) {
        let goalIDs = Set(goals.map(\.id))
        for step in steps {
            guard goalIDs.contains(step.goalID) else { throw .unknownGoal(step.goalID) }
            guard GoalStep.targetRange.contains(step.target) else { throw .invalidPlan }
        }
        let stepGoals = Dictionary(steps.map { ($0.id, $0.goalID) }, uniquingKeysWith: { first, _ in first })
        for quest in quests {
            guard let stepID = quest.stepID else { continue }
            guard stepGoals[stepID] == quest.goalID else { throw .invalidPlan }
        }
    }
}

extension String {
    fileprivate var trimmed: String { trimmingCharacters(in: .whitespacesAndNewlines) }
}
