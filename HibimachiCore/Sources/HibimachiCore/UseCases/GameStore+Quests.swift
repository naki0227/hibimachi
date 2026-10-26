import Foundation

/// P1 use cases: goals, today's quests, completion rewards (once per completion) and undoing a mis-tap.
extension GameStore {
    public var todaysQuests: [QuestTemplate] { DailyPlanner.suggestions(for: today, in: progress) }

    public var completedToday: [QuestCompletion] { progress.completions(on: today) }

    @discardableResult
    public func addGoal(title: String, category: GoalCategory) -> Bool {
        apply { progress in
            progress.addGoal(title: title, category: category, at: nowForProgress, makeID: makeIDForProgress)
        }
    }

    @discardableResult
    public func archiveGoal(_ id: UUID) -> Bool {
        apply { progress in progress.archiveGoal(id) }
    }

    @discardableResult
    public func addQuest(to goalID: UUID, title: String, minutes: Int) -> Bool {
        let id = makeIDForProgress()
        return apply { progress in progress.addQuest(to: goalID, title: title, minutes: minutes, id: id) }
    }

    public func skipQuest(_ id: UUID) {
        updateProgress { $0.skip(id, on: today) }
    }

    /// One tap: record the completion and grant XP + きらめき exactly once.
    @discardableResult
    public func completeQuest(_ id: UUID) -> Bool {
        let completionID = makeIDForProgress()
        let transactionID = makeIDForProgress()
        var reward: RewardTransaction?
        let ok = apply { progress in
            let result = progress.complete(
                id, on: today, at: nowForProgress, completionID: completionID, transactionID: transactionID)
            if case .success(let transaction) = result { reward = transaction }
            return result
        }
        if ok, let reward { setLastCompletion((completionID, reward)) }
        return ok
    }

    /// Takes back the last completion (same day only, and only if its きらめき were not spent).
    @discardableResult
    public func undoLastCompletion() -> Bool {
        guard let last = lastCompletion else { return false }
        let transactionID = makeIDForProgress()
        let ok = apply { progress in
            progress.undoCompletion(last.completionID, today: today, at: nowForProgress, transactionID: transactionID)
        }
        if ok { setLastCompletion(nil) }
        return ok
    }

    public func dismissLastCompletion() {
        setLastCompletion(nil)
    }

    /// Runs a progress mutation; on success saves, on failure keeps the state and records why.
    private func apply<T>(_ change: (inout PlayerProgress) -> Result<T, ProgressError>) -> Bool {
        var result: Result<T, ProgressError> = .failure(.emptyTitle)
        updateProgress { result = change(&$0) }
        switch result {
        case .success:
            clearProgressError()
            return true
        case .failure(let error):
            recordProgressError(error)
            return false
        }
    }
}
