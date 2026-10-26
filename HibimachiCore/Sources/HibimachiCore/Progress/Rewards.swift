import Foundation

/// Reward and price table. One common currency ("きらめき") for every activity (user decision 2026-10-26).
/// Values are provisional (GAME-DESIGN "初期XPの例") and versioned so old transactions keep their meaning.
public enum RewardRule {
    public static let version = 1
    public static let questXP = 20
    public static let questSparkles = 5
    /// Given once when progress starts (new island or migrated save) so building is possible from day one.
    public static let welcomeSparkles = 30
    public static let xpPerLevel = 100

    public static func price(of kind: ObjectKind) -> Int {
        switch kind {
        case .flower: 5
        case .bench, .lamp, .roundTree, .pineTree: 10
        case .pond: 20
        case .house: 30
        }
    }

    public static func level(forXP xp: Int) -> Int { 1 + max(xp, 0) / xpPerLevel }
}

/// One immutable ledger line. Balances are always derived from the ledger, never stored separately.
public struct RewardTransaction: Identifiable, Equatable, Sendable {
    public enum Reason: Equatable, Sendable {
        case welcome
        case questCompleted(completionID: UUID)
        case questUndone(completionID: UUID)
        case purchase(ObjectKind)
    }

    public let id: UUID
    public let reason: Reason
    public let xpDelta: Int
    public let sparkleDelta: Int
    public let ruleVersion: Int
    public let date: Date

    public init(id: UUID, reason: Reason, xpDelta: Int, sparkleDelta: Int, ruleVersion: Int, date: Date) {
        self.id = id
        self.reason = reason
        self.xpDelta = xpDelta
        self.sparkleDelta = sparkleDelta
        self.ruleVersion = ruleVersion
        self.date = date
    }
}

public enum ProgressError: Error, Equatable, Sendable {
    case emptyTitle
    case titleTooLong(limit: Int)
    case tooManyGoals(limit: Int)
    case unknownGoal(UUID)
    case unknownQuest(UUID)
    case unknownCompletion(UUID)
    case goalArchived(UUID)
    case alreadyCompletedToday(UUID)
    case alreadyRewarded(UUID)
    case undoOnlySameDay
    case notEnoughSparkles(needed: Int, balance: Int)
    case invalidMinutes
    case duplicateID(UUID)
    case negativeBalance
}
