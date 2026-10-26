import Foundation

/// Life areas a goal can belong to. Categories only pick preset quests; rewards are identical for all of them
/// (GAME-DESIGN: no category-specific currency, nothing locked behind a kind of activity).
public enum GoalCategory: String, CaseIterable, Sendable {
    case tidy
    case study
    case rest
    case create
    case move
    case other
}

public struct Goal: Identifiable, Equatable, Sendable {
    public static let titleLimit = 30

    public let id: UUID
    public var title: String
    public let category: GoalCategory
    public let createdAt: Date
    /// Archived goals stop producing quests but keep their history.
    public var isArchived: Bool

    public init(id: UUID, title: String, category: GoalCategory, createdAt: Date, isArchived: Bool = false) {
        self.id = id
        self.title = title
        self.category = category
        self.createdAt = createdAt
        self.isArchived = isArchived
    }
}

/// A small, finishable action (5–15 minutes) under a goal.
public struct QuestTemplate: Identifiable, Equatable, Sendable {
    public static let minutesRange = 1...60

    public let id: UUID
    public let goalID: UUID
    public var title: String
    public var minutes: Int

    public init(id: UUID, goalID: UUID, title: String, minutes: Int) {
        self.id = id
        self.goalID = goalID
        self.title = title
        self.minutes = minutes
    }
}

/// "I did it" record. Self-reported: it is a diary entry, not proof, and nothing punishes skipping.
public struct QuestCompletion: Identifiable, Equatable, Sendable {
    public let id: UUID
    public let questID: UUID
    public let goalID: UUID
    public let day: LocalDay
    public let completedAt: Date

    public init(id: UUID, questID: UUID, goalID: UUID, day: LocalDay, completedAt: Date) {
        self.id = id
        self.questID = questID
        self.goalID = goalID
        self.day = day
        self.completedAt = completedAt
    }
}

/// Built-in quest ideas per category (rule-based, no AI). Players can add their own too.
public enum QuestPresets {
    public static func quests(for category: GoalCategory) -> [(title: String, minutes: Int)] {
        switch category {
        case .tidy: [("机の上を5分だけ片付ける", 5), ("出しっぱなしを3つ戻す", 5), ("ゴミをひとまとめにする", 10)]
        case .study: [("教科書を2ページ読む", 10), ("単語を5つ覚える", 10), ("昨日のノートを見返す", 5)]
        case .rest: [("深呼吸を10回する", 5), ("水を一杯ゆっくり飲む", 5), ("5分だけ目を閉じて休む", 5)]
        case .create: [("アイデアを3つメモする", 5), ("10分だけ作品に触る", 10), ("好きな作品を1つ眺める", 5)]
        case .move: [("ストレッチを5分する", 5), ("外の空気を吸いに出る", 10), ("階段を使ってみる", 5)]
        case .other: [("5分だけ取りかかる", 5), ("次の一歩を1行メモする", 5), ("10分だけ続きをやる", 10)]
        }
    }
}
