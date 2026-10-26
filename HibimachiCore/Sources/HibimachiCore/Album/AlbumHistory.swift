import Foundation

/// One day of the island's history: quests done, buildings bought and memories, newest day first.
public struct AlbumDay: Identifiable, Equatable, Sendable {
    public struct DoneQuest: Equatable, Sendable {
        public let completionID: UUID
        public let title: String
    }

    public var id: LocalDay { day }
    public let day: LocalDay
    public let quests: [DoneQuest]
    public let purchases: [ObjectKind]
    public let sparklesEarned: Int
    public let memories: [MemoryEntry]

    public static func history(progress: PlayerProgress, album: Album, calendar: Calendar) -> [AlbumDay] {
        var quests: [LocalDay: [DoneQuest]] = [:]
        for completion in progress.completions.sorted(by: { $0.completedAt < $1.completedAt }) {
            let title = progress.quests.first { $0.id == completion.questID }?.title ?? ""
            quests[completion.day, default: []].append(DoneQuest(completionID: completion.id, title: title))
        }
        var purchases: [LocalDay: [ObjectKind]] = [:]
        var earned: [LocalDay: Int] = [:]
        for transaction in progress.ledger.sorted(by: { $0.date < $1.date }) {
            let day = LocalDay(date: transaction.date, calendar: calendar)
            switch transaction.reason {
            case .purchase(let kind): purchases[day, default: []].append(kind)
            case .questCompleted, .questUndone: earned[day, default: 0] += transaction.sparkleDelta
            case .welcome: break
            }
        }
        var memories: [LocalDay: [MemoryEntry]] = [:]
        for entry in album.entries.sorted(by: { $0.createdAt < $1.createdAt }) {
            memories[entry.day, default: []].append(entry)
        }
        let days = Set(quests.keys).union(purchases.keys).union(memories.keys)
        return days.sorted(by: >).map { day in
            AlbumDay(
                day: day, quests: quests[day] ?? [], purchases: purchases[day] ?? [],
                sparklesEarned: max(0, earned[day] ?? 0), memories: memories[day] ?? [])
        }
    }
}
