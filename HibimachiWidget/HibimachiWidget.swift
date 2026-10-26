import HibimachiCore
import SwiftUI
import WidgetKit

@main
struct HibimachiWidgetBundle: WidgetBundle {
    var body: some Widget {
        IslandWidget()
    }
}

struct IslandWidget: Widget {
    static let kind = "IslandWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: Self.kind, provider: IslandTimelineProvider()) { entry in
            FamilyView(entry: entry)
                .containerBackground(for: .widget) { IslandWidgetBackground() }
        }
        .configurationDisplayName("ひびまち")
        .description("島のようすと、きょうのクエスト。")
        .supportedFamilies([.systemSmall, .systemMedium, .systemLarge])
    }
}

/// Reads the family from the environment; the shared view takes it as a parameter so the app can preview it.
private struct FamilyView: View {
    let entry: IslandWidgetEntry
    @Environment(\.widgetFamily) private var family

    var body: some View { IslandWidgetView(entry: entry, family: family) }
}

struct IslandTimelineProvider: TimelineProvider {
    func placeholder(in context: Context) -> IslandWidgetEntry {
        IslandWidgetEntry(date: Date(), board: nil, island: nil)
    }

    func getSnapshot(in context: Context, completion: @escaping (IslandWidgetEntry) -> Void) {
        completion(Self.entry(at: Date()))
    }

    /// One entry now, refreshed at the next local midnight when today's quests change. The app and the
    /// "やった！" intent also ask WidgetKit to reload after they change the save.
    func getTimeline(in context: Context, completion: @escaping (Timeline<IslandWidgetEntry>) -> Void) {
        let now = Date()
        let midnight = Calendar.current.nextDate(
            after: now, matching: DateComponents(hour: 0, minute: 0), matchingPolicy: .nextTime)
        completion(Timeline(entries: [Self.entry(at: now)], policy: midnight.map { .after($0) } ?? .atEnd))
    }

    static func entry(at date: Date) -> IslandWidgetEntry {
        let board = SharedContainer.sharedRepository?.peek().map {
            QuestBoard.make(progress: $0.progress, day: LocalDay(date: date, calendar: .current))
        }
        return IslandWidgetEntry(date: date, board: board, island: SharedContainer.loadIslandImage())
    }
}
