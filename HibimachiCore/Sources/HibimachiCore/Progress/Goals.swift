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
    /// No longer suggested. Kept (not deleted) when past completions point at it, so history stays intact.
    public var isRetired: Bool
    /// The goal step it belongs to (ADR-0016). `nil`: an everyday quest of the goal, suggested at any step.
    public var stepID: UUID?

    public init(
        id: UUID, goalID: UUID, title: String, minutes: Int, isRetired: Bool = false, stepID: UUID? = nil
    ) {
        self.id = id
        self.goalID = goalID
        self.title = title
        self.minutes = minutes
        self.isRetired = isRetired
        self.stepID = stepID
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
/// The titles are copied into the player's goals when created, so they follow the language at that moment.
public enum QuestPresets {
    public enum Language: Sendable {
        case japanese
        case english
    }

    public static func quests(for category: GoalCategory, language: Language = .japanese)
        -> [(title: String, minutes: Int)]
    {
        language == .english ? englishQuests(for: category) : japaneseQuests(for: category)
    }

    static func englishQuests(for category: GoalCategory) -> [(title: String, minutes: Int)] {
        switch category {
        case .tidy:
            [("Clear the desk for 5 minutes", 5), ("Put 3 things back in place", 5), ("Gather the trash", 10)]
        case .study:
            [("Read 2 pages of a textbook", 10), ("Learn 5 new words", 10), ("Look over yesterday's notes", 5)]
        case .rest:
            [("Take 10 slow breaths", 5), ("Drink a glass of water slowly", 5), ("Close your eyes for 5 minutes", 5)]
        case .create:
            [("Jot down 3 ideas", 5), ("Create for 10 minutes", 10), ("Enjoy one work you love", 5)]
        case .move: [("Stretch for 5 minutes", 5), ("Step outside for fresh air", 10), ("Take the stairs", 5)]
        case .other:
            [("Start it for just 5 minutes", 5), ("Write down the next step", 5), ("Keep going for 10 minutes", 10)]
        }
    }

    static func japaneseQuests(for category: GoalCategory) -> [(title: String, minutes: Int)] {
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
