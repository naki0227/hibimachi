import Foundation

/// Today's quests as a short checklist, for places outside the island screen (the home-screen widget).
/// Open suggestions come first, then what was already done today.
public struct QuestBoard: Equatable, Sendable {
    public struct Item: Identifiable, Equatable, Sendable {
        /// The quest template's ID (what a "done" button completes).
        public let id: UUID
        public let title: String
        public let goalTitle: String
        public let minutes: Int
        public let isDone: Bool

        public init(id: UUID, title: String, goalTitle: String, minutes: Int, isDone: Bool) {
            self.id = id
            self.title = title
            self.goalTitle = goalTitle
            self.minutes = minutes
            self.isDone = isDone
        }
    }

    public let day: LocalDay
    public let items: [Item]
    public let level: Int
    public let sparkles: Int
    /// `false` until the player picks a first goal; the widget then invites them into the app.
    public let hasGoals: Bool

    public init(day: LocalDay, items: [Item], level: Int, sparkles: Int, hasGoals: Bool) {
        self.day = day
        self.items = items
        self.level = level
        self.sparkles = sparkles
        self.hasGoals = hasGoals
    }

    public var remaining: Int { items.filter { !$0.isDone }.count }

    public static func make(progress: PlayerProgress, day: LocalDay) -> QuestBoard {
        let goalTitles = Dictionary(progress.goals.map { ($0.id, $0.title) }, uniquingKeysWith: { first, _ in first })
        func item(_ quest: QuestTemplate, done: Bool) -> Item {
            Item(
                id: quest.id, title: quest.title, goalTitle: goalTitles[quest.goalID] ?? "", minutes: quest.minutes,
                isDone: done)
        }
        let open = DailyPlanner.suggestions(for: day, in: progress).map { item($0, done: false) }
        var seen = Set<UUID>()
        let done = progress.completions(on: day)
            .sorted { $0.completedAt < $1.completedAt }
            .compactMap { completion -> Item? in
                guard seen.insert(completion.questID).inserted,
                    let quest = progress.quests.first(where: { $0.id == completion.questID })
                else { return nil }
                return item(quest, done: true)
            }
        return QuestBoard(
            day: day, items: open + done, level: progress.level, sparkles: progress.sparkles,
            hasGoals: !progress.activeGoals.isEmpty)
    }
}
