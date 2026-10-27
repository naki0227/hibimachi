import Foundation

/// Life-side state (P1): goals, quests, completions, the reward ledger and owned buildings.
/// Every mutation validates first and changes nothing on failure.
public struct PlayerProgress: Equatable, Sendable {
    public static let activeGoalLimit = 3

    // Set from the goal and step extensions (PlayerProgress+Goals/Steps.swift).
    public internal(set) var goals: [Goal]
    public internal(set) var quests: [QuestTemplate]
    /// Middle steps of goals, in order within each goal (ADR-0016).
    public internal(set) var steps: [GoalStep]
    public private(set) var completions: [QuestCompletion]
    public private(set) var ledger: [RewardTransaction]
    /// Buildings the player owns (placed or in storage). Placing uses one; putting away returns it.
    public private(set) var owned: [ObjectKind: Int]
    /// Quests skipped today (only the current day is kept).
    public private(set) var skipped: (day: LocalDay, questIDs: Set<UUID>)?

    public init(
        goals: [Goal] = [], quests: [QuestTemplate] = [], steps: [GoalStep] = [], completions: [QuestCompletion] = [],
        ledger: [RewardTransaction] = [], owned: [ObjectKind: Int] = [:],
        skipped: (day: LocalDay, questIDs: Set<UUID>)? = nil
    ) throws(ProgressError) {
        self.goals = goals
        self.quests = quests
        self.steps = steps
        self.completions = completions
        self.ledger = ledger
        self.owned = owned
        self.skipped = skipped
        try validate()
    }

    /// Fresh progress for an island: owns what is already placed and gets the welcome gift.
    public static func starting(for world: World, at date: Date, id: UUID) -> PlayerProgress {
        var owned: [ObjectKind: Int] = [:]
        for object in world.objects { owned[object.kind, default: 0] += 1 }
        let gift = RewardTransaction(
            id: id, reason: .welcome, xpDelta: 0, sparkleDelta: RewardRule.welcomeSparkles,
            ruleVersion: RewardRule.version, date: date)
        // Valid by construction: one transaction, positive balance, no references.
        return PlayerProgress(unvalidatedLedger: [gift], owned: owned)
    }

    private init(unvalidatedLedger ledger: [RewardTransaction], owned: [ObjectKind: Int]) {
        goals = []
        quests = []
        steps = []
        completions = []
        self.ledger = ledger
        self.owned = owned
        skipped = nil
    }

    public static func == (lhs: PlayerProgress, rhs: PlayerProgress) -> Bool {
        lhs.goals == rhs.goals && lhs.quests == rhs.quests && lhs.steps == rhs.steps
            && lhs.completions == rhs.completions
            && lhs.ledger == rhs.ledger && lhs.owned == rhs.owned && lhs.skipped?.day == rhs.skipped?.day
            && lhs.skipped?.questIDs == rhs.skipped?.questIDs
    }

    // MARK: Derived values

    public var sparkles: Int { ledger.reduce(0) { $0 + $1.sparkleDelta } }
    public var totalXP: Int { ledger.reduce(0) { $0 + $1.xpDelta } }
    public var level: Int { RewardRule.level(forXP: totalXP) }
    public var activeGoals: [Goal] { goals.filter { !$0.isArchived } }

    public func quests(of goalID: UUID) -> [QuestTemplate] { quests.filter { $0.goalID == goalID } }
    /// Quests still suggested for a goal (not retired).
    public func activeQuests(of goalID: UUID) -> [QuestTemplate] { quests(of: goalID).filter { !$0.isRetired } }

    public func isCompleted(_ questID: UUID, on day: LocalDay) -> Bool {
        completions.contains { $0.questID == questID && $0.day == day }
    }

    public func completions(on day: LocalDay) -> [QuestCompletion] { completions.filter { $0.day == day } }

    /// Owned but not placed.
    public func available(_ kind: ObjectKind, in world: World) -> Int {
        max(owned[kind, default: 0] - world.objects.filter { $0.kind == kind }.count, 0)
    }

    // MARK: Skipping

    public mutating func skip(_ questID: UUID, on day: LocalDay) {
        var ids = skipped?.day == day ? skipped?.questIDs ?? [] : []
        ids.insert(questID)
        skipped = (day, ids)
    }

    public func isSkipped(_ questID: UUID, on day: LocalDay) -> Bool {
        skipped?.day == day && skipped?.questIDs.contains(questID) == true
    }

    // MARK: Rewards

    /// Records a completion and grants the reward exactly once. Replaying the same completion ID is rejected.
    public mutating func complete(
        _ questID: UUID, on day: LocalDay, at date: Date, completionID: UUID, transactionID: UUID
    ) -> Result<RewardTransaction, ProgressError> {
        guard let quest = quests.first(where: { $0.id == questID }) else { return .failure(.unknownQuest(questID)) }
        guard goals.first(where: { $0.id == quest.goalID })?.isArchived == false else {
            return .failure(.goalArchived(quest.goalID))
        }
        guard !isCompleted(questID, on: day) else { return .failure(.alreadyCompletedToday(questID)) }
        guard !hasReward(for: completionID), !completions.contains(where: { $0.id == completionID }) else {
            return .failure(.alreadyRewarded(completionID))
        }
        let completion = QuestCompletion(
            id: completionID, questID: questID, goalID: quest.goalID, day: day, completedAt: date)
        let amount = RewardRule.questReward(minutes: quest.minutes)
        let reward = RewardTransaction(
            id: transactionID, reason: .questCompleted(completionID: completionID), xpDelta: amount.xp,
            sparkleDelta: amount.sparkles, ruleVersion: RewardRule.version, date: date)
        completions.append(completion)
        ledger.append(reward)
        return .success(reward)
    }

    /// The small bonus for a complete record (ADR-0015). Once per completion; the completion must exist.
    public mutating func grantRecordBonus(
        for completionID: UUID, check: RecordCheck, at date: Date, transactionID: UUID
    ) -> Result<RewardTransaction, ProgressError> {
        guard completions.contains(where: { $0.id == completionID }) else {
            return .failure(.unknownCompletion(completionID))
        }
        guard check.isComplete else { return .failure(.incompleteRecord) }
        guard !ledger.contains(where: { $0.reason == .recordBonus(completionID: completionID) }) else {
            return .failure(.alreadyRewarded(completionID))
        }
        let bonus = RewardTransaction(
            id: transactionID, reason: .recordBonus(completionID: completionID), xpDelta: RewardRule.recordBonusXP,
            sparkleDelta: RewardRule.recordBonusSparkles, ruleVersion: RewardRule.version, date: date)
        ledger.append(bonus)
        return .success(bonus)
    }

    /// Takes back a same-day completion (e.g. a mis-tap). The reward is reversed with a ledger line, so a later
    /// re-completion is not a second reward. Refused if the きらめき were already spent.
    public mutating func undoCompletion(
        _ completionID: UUID, today: LocalDay, at date: Date, transactionID: UUID
    ) -> Result<RewardTransaction, ProgressError> {
        guard let index = completions.firstIndex(where: { $0.id == completionID }) else {
            return .failure(.unknownCompletion(completionID))
        }
        guard completions[index].day == today else { return .failure(.undoOnlySameDay) }
        guard
            let granted = ledger.first(where: { $0.reason == .questCompleted(completionID: completionID) })
        else { return .failure(.unknownCompletion(completionID)) }
        // The record bonus goes back with the quest's reward.
        let bonus = ledger.first { $0.reason == .recordBonus(completionID: completionID) }
        let xp = granted.xpDelta + (bonus?.xpDelta ?? 0)
        let sparkleTotal = granted.sparkleDelta + (bonus?.sparkleDelta ?? 0)
        guard sparkles >= sparkleTotal else {
            return .failure(.notEnoughSparkles(needed: sparkleTotal, balance: sparkles))
        }
        let reversal = RewardTransaction(
            id: transactionID, reason: .questUndone(completionID: completionID), xpDelta: -xp,
            sparkleDelta: -sparkleTotal, ruleVersion: granted.ruleVersion, date: date)
        completions.remove(at: index)
        ledger.append(reversal)
        return .success(reversal)
    }

    public mutating func purchase(
        _ kind: ObjectKind, at date: Date, transactionID: UUID
    ) -> Result<RewardTransaction, ProgressError> {
        let price = RewardRule.price(of: kind)
        guard sparkles >= price else { return .failure(.notEnoughSparkles(needed: price, balance: sparkles)) }
        let spend = RewardTransaction(
            id: transactionID, reason: .purchase(kind), xpDelta: 0, sparkleDelta: -price,
            ruleVersion: RewardRule.version, date: date)
        ledger.append(spend)
        owned[kind, default: 0] += 1
        return .success(spend)
    }

    /// Ensures owned counts cover what is placed (repairs old or hand-edited saves instead of failing).
    mutating func reconcileOwnership(with world: World) {
        for object in world.objects {
            let placed = world.objects.filter { $0.kind == object.kind }.count
            owned[object.kind] = max(owned[object.kind, default: 0], placed)
        }
    }

    // MARK: Validation

    private func hasReward(for completionID: UUID) -> Bool {
        ledger.contains { $0.reason == .questCompleted(completionID: completionID) }
    }

    static func titleIssue(_ title: String, limit: Int) -> ProgressError? {
        if title.isEmpty { return .emptyTitle }
        if title.count > limit { return .titleTooLong(limit: limit) }
        return nil
    }

    private func validate() throws(ProgressError) {
        var seen = Set<UUID>()
        let ids = goals.map(\.id) + quests.map(\.id) + steps.map(\.id) + completions.map(\.id) + ledger.map(\.id)
        for id in ids {
            guard seen.insert(id).inserted else { throw .duplicateID(id) }
        }
        let goalIDs = Set(goals.map(\.id))
        for quest in quests where !goalIDs.contains(quest.goalID) { throw .unknownGoal(quest.goalID) }
        try validateSteps()
        let questIDs = Set(quests.map(\.id))
        for completion in completions where !questIDs.contains(completion.questID) {
            throw .unknownQuest(completion.questID)
        }
        var rewarded = Set<UUID>()
        for case .questCompleted(let completionID) in ledger.map(\.reason) {
            guard rewarded.insert(completionID).inserted else { throw .alreadyRewarded(completionID) }
        }
        var bonused = Set<UUID>()
        for case .recordBonus(let completionID) in ledger.map(\.reason) {
            guard bonused.insert(completionID).inserted else { throw .alreadyRewarded(completionID) }
        }
        guard sparkles >= 0 else { throw .negativeBalance }
    }
}
