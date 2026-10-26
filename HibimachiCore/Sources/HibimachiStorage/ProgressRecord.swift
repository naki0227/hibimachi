import Foundation
import HibimachiCore

/// On-disk form of `PlayerProgress` (added in schema v2).
struct ProgressRecord: Codable, Equatable {
    struct GoalRecord: Codable, Equatable {
        var id: UUID
        var title: String
        var category: String
        var createdAt: Date
        var archived: Bool
    }

    struct QuestRecord: Codable, Equatable {
        var id: UUID
        var goalID: UUID
        var title: String
        var minutes: Int
        /// Absent in older saves: still suggested.
        var retired: Bool?
    }

    struct CompletionRecord: Codable, Equatable {
        var id: UUID
        var questID: UUID
        var goalID: UUID
        var day: String
        var completedAt: Date
    }

    struct TransactionRecord: Codable, Equatable {
        /// "welcome" | "quest" | "undo" | "purchase"
        var reason: String
        /// Completion ID for quest/undo, object kind for purchase.
        var reference: String?
        var id: UUID
        var xp: Int
        var sparkles: Int
        var ruleVersion: Int
        var date: Date
    }

    var goals: [GoalRecord]
    var quests: [QuestRecord]
    var completions: [CompletionRecord]
    var transactions: [TransactionRecord]
    var owned: [String: Int]
    var skippedDay: String?
    var skippedQuestIDs: [UUID]
}

enum ProgressRecordError: Error, Equatable, CustomStringConvertible {
    case unknownCategory(String)
    case unknownReason(String)
    case badReference(String?)
    case badDay(String)
    case unknownObjectKind(String)
    case invalidProgress(ProgressError)

    var description: String {
        switch self {
        case .unknownCategory(let value): "unknown goal category '\(value)'"
        case .unknownReason(let value): "unknown transaction reason '\(value)'"
        case .badReference(let value): "bad transaction reference '\(value ?? "nil")'"
        case .badDay(let value): "bad day '\(value)'"
        case .unknownObjectKind(let value): "unknown object kind '\(value)'"
        case .invalidProgress(let error): "invalid progress: \(error)"
        }
    }
}

extension ProgressRecord {
    init(_ progress: PlayerProgress) {
        goals = progress.goals.map {
            GoalRecord(
                id: $0.id, title: $0.title, category: $0.category.rawValue, createdAt: $0.createdAt,
                archived: $0.isArchived)
        }
        quests = progress.quests.map {
            QuestRecord(
                id: $0.id, goalID: $0.goalID, title: $0.title, minutes: $0.minutes, retired: $0.isRetired ? true : nil)
        }
        completions = progress.completions.map {
            CompletionRecord(
                id: $0.id, questID: $0.questID, goalID: $0.goalID, day: $0.day.description, completedAt: $0.completedAt)
        }
        transactions = progress.ledger.map { transaction in
            let (reason, reference): (String, String?) =
                switch transaction.reason {
                case .welcome: ("welcome", nil)
                case .questCompleted(let id): ("quest", id.uuidString)
                case .questUndone(let id): ("undo", id.uuidString)
                case .purchase(let kind): ("purchase", kind.rawValue)
                }
            return TransactionRecord(
                reason: reason, reference: reference, id: transaction.id, xp: transaction.xpDelta,
                sparkles: transaction.sparkleDelta, ruleVersion: transaction.ruleVersion, date: transaction.date)
        }
        owned = Dictionary(uniqueKeysWithValues: progress.owned.map { ($0.key.rawValue, $0.value) })
        skippedDay = progress.skipped?.day.description
        skippedQuestIDs = progress.skipped.map { Array($0.questIDs).sorted { $0.uuidString < $1.uuidString } } ?? []
    }

    func makeProgress() throws -> PlayerProgress {
        let goals = try goals.map { record in
            guard let category = GoalCategory(rawValue: record.category) else {
                throw ProgressRecordError.unknownCategory(record.category)
            }
            return Goal(
                id: record.id, title: record.title, category: category, createdAt: record.createdAt,
                isArchived: record.archived)
        }
        let quests = quests.map {
            QuestTemplate(
                id: $0.id, goalID: $0.goalID, title: $0.title, minutes: $0.minutes, isRetired: $0.retired ?? false)
        }
        let completions = try completions.map { record in
            guard let day = LocalDay(string: record.day) else { throw ProgressRecordError.badDay(record.day) }
            return QuestCompletion(
                id: record.id, questID: record.questID, goalID: record.goalID, day: day, completedAt: record.completedAt
            )
        }
        let ledger = try transactions.map { record in
            RewardTransaction(
                id: record.id, reason: try Self.reason(record), xpDelta: record.xp, sparkleDelta: record.sparkles,
                ruleVersion: record.ruleVersion, date: record.date)
        }
        var ownedKinds: [ObjectKind: Int] = [:]
        for (raw, count) in owned {
            guard let kind = ObjectKind(rawValue: raw) else { throw ProgressRecordError.unknownObjectKind(raw) }
            ownedKinds[kind] = max(count, 0)
        }
        var skipped: (day: LocalDay, questIDs: Set<UUID>)?
        if let skippedDay {
            guard let day = LocalDay(string: skippedDay) else { throw ProgressRecordError.badDay(skippedDay) }
            skipped = (day, Set(skippedQuestIDs))
        }
        do {
            return try PlayerProgress(
                goals: goals, quests: quests, completions: completions, ledger: ledger, owned: ownedKinds,
                skipped: skipped)
        } catch {
            throw ProgressRecordError.invalidProgress(error)
        }
    }

    private static func reason(_ record: TransactionRecord) throws -> RewardTransaction.Reason {
        switch record.reason {
        case "welcome":
            return .welcome
        case "quest", "undo":
            guard let reference = record.reference, let id = UUID(uuidString: reference) else {
                throw ProgressRecordError.badReference(record.reference)
            }
            return record.reason == "quest" ? .questCompleted(completionID: id) : .questUndone(completionID: id)
        case "purchase":
            guard let reference = record.reference, let kind = ObjectKind(rawValue: reference) else {
                throw ProgressRecordError.badReference(record.reference)
            }
            return .purchase(kind)
        default:
            throw ProgressRecordError.unknownReason(record.reason)
        }
    }
}
