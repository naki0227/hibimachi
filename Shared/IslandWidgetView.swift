import AppIntents
import HibimachiCore
import SwiftUI
import WidgetKit

struct IslandWidgetEntry: TimelineEntry {
    let date: Date
    /// `nil` when there is no readable save yet (or no shared container).
    let board: QuestBoard?
    let island: CGImage?
    var placedCount = 0
    var discoveryCount = 0
}

/// Home-screen widget: the island on the left, today's quests on the right (one tap = "やった！").
/// Lives in Shared/ so the app can render the same view for its preview and UI-test screenshots.
struct IslandWidgetView: View {
    let entry: IslandWidgetEntry
    let family: WidgetFamily

    var body: some View {
        switch family {
        case .systemSmall:
            IslandTile(image: entry.island, board: entry.board, showsRemaining: true)
        case .systemLarge:
            HStack(spacing: 12) {
                VStack(spacing: 8) {
                    IslandTile(image: entry.island, board: entry.board, showsRemaining: false)
                        .aspectRatio(1, contentMode: .fit)
                    if let board = entry.board {
                        StatusRow(board: board)
                        IslandFacts(placed: entry.placedCount, discovered: entry.discoveryCount)
                    }
                    Spacer(minLength: 0)
                }
                .frame(maxWidth: .infinity)
                QuestList(board: entry.board, limit: 6, detailed: true)
                    .frame(maxWidth: .infinity)
            }
        default:
            HStack(spacing: 10) {
                IslandTile(image: entry.island, board: entry.board, showsRemaining: false)
                    .frame(maxWidth: .infinity)
                QuestList(board: entry.board, limit: 3, detailed: false)
                    .frame(maxWidth: .infinity)
            }
        }
    }
}

/// Paper background shared by the widget (`containerBackground`) and the in-app preview.
struct IslandWidgetBackground: View {
    var body: some View { GameColor.paper }
}

private struct IslandTile: View {
    let image: CGImage?
    let board: QuestBoard?
    let showsRemaining: Bool

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [GameColor.sky.opacity(0.55), GameColor.sky], startPoint: .top, endPoint: .bottom)
            if let image {
                Image(decorative: image, scale: 1)
                    .interpolation(.none)
                    .resizable()
                    .scaledToFit()
                    // The picture's corners are open sea; zoom in a little so the island itself reads larger.
                    .scaleEffect(1.18)
            } else {
                Image(systemName: "leaf.fill")
                    .font(.system(size: 30, weight: .bold))
                    .foregroundStyle(.white)
            }
        }
        .overlay(alignment: .bottom) {
            if showsRemaining, let board, board.hasGoals {
                Text(board.remaining > 0 ? String(localized: "のこり \(board.remaining)") : String(localized: "ぜんぶできた！"))
                    .font(GameFont.body(12, weight: .heavy))
                    .foregroundStyle(GameColor.ink)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                    .background(GameColor.paper, in: Capsule())
                    .overlay(Capsule().stroke(GameColor.line, lineWidth: 2))
                    .padding(.bottom, 8)
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: 18))
        .overlay(RoundedRectangle(cornerRadius: 18).stroke(GameColor.line, lineWidth: 2.5))
        .accessibilityElement()
        .accessibilityLabel("ひびまちの島")
    }
}

private struct StatusRow: View {
    let board: QuestBoard

    var body: some View {
        HStack(spacing: 6) {
            chip("leaf.fill", "Lv\(board.level)", GameColor.leaf)
            chip("sparkles", "\(board.sparkles)", GameColor.sun)
        }
    }

    private func chip(_ symbol: String, _ text: String, _ tint: Color) -> some View {
        HStack(spacing: 3) {
            Image(systemName: symbol).foregroundStyle(tint)
            Text(text).monospacedDigit().foregroundStyle(GameColor.ink)
        }
        .font(GameFont.body(12, weight: .heavy))
        .padding(.horizontal, 8)
        .frame(minHeight: 24)
        .background(.white, in: Capsule())
        .overlay(Capsule().stroke(GameColor.line, lineWidth: 2))
    }
}

private struct IslandFacts: View {
    let placed: Int
    let discovered: Int

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Label("置いたもの \(placed)こ", systemImage: "house.fill")
            Label("見つけた姿 \(discovered)", systemImage: "book.closed.fill")
        }
        .font(GameFont.body(11, weight: .bold))
        .foregroundStyle(GameColor.inkSoft)
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 4)
    }
}

private struct QuestList: View {
    let board: QuestBoard?
    let limit: Int
    let detailed: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: detailed ? 8 : 5) {
            header
            if let board, board.hasGoals {
                ForEach(board.items.prefix(limit)) { item in
                    QuestItemRow(item: item, detailed: detailed)
                }
                if detailed {
                    Spacer(minLength: 0)
                    Text("○をタップで「やった！」")
                        .font(GameFont.caption(10))
                        .foregroundStyle(GameColor.inkSoft)
                }
            } else {
                Text(
                    board == nil
                        ? String(localized: "アプリをひらいて、島をはじめよう") : String(localized: "アプリで目標をえらぶと、ここに今日のクエストが並びます")
                )
                .font(GameFont.body(12, weight: .medium))
                .foregroundStyle(GameColor.inkSoft)
                .fixedSize(horizontal: false, vertical: true)
            }
            if !detailed { Spacer(minLength: 0) }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    private var header: some View {
        HStack(spacing: 4) {
            Text("きょうのこと")
                .font(GameFont.body(14, weight: .heavy))
                .foregroundStyle(GameColor.ink)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
            Spacer(minLength: 0)
            if let board, board.hasGoals {
                Text(board.remaining > 0 ? String(localized: "のこり\(board.remaining)") : String(localized: "完了"))
                    .font(GameFont.body(10, weight: .heavy))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(board.remaining > 0 ? GameColor.apricot : GameColor.leaf, in: Capsule())
            }
        }
    }
}

private struct QuestItemRow: View {
    let item: QuestBoard.Item
    let detailed: Bool

    var body: some View {
        if item.isDone {
            content
        } else {
            Button(intent: CompleteQuestIntent(questID: item.id)) { content }
                .buttonStyle(.plain)
                .accessibilityLabel("\(item.title)をやった！にする")
        }
    }

    private var content: some View {
        HStack(alignment: .top, spacing: 6) {
            ZStack {
                Circle().fill(item.isDone ? GameColor.leaf : .white)
                Circle().stroke(item.isDone ? GameColor.leafDark : GameColor.line, lineWidth: 2)
                if item.isDone {
                    Image(systemName: "checkmark").font(.system(size: 10, weight: .black)).foregroundStyle(.white)
                }
            }
            .frame(width: 20, height: 20)
            VStack(alignment: .leading, spacing: 1) {
                Text(item.title)
                    .font(GameFont.body(detailed ? 13 : 12, weight: .bold))
                    .strikethrough(item.isDone, color: GameColor.inkSoft)
                    .foregroundStyle(item.isDone ? GameColor.inkSoft : GameColor.ink)
                    .lineLimit(detailed ? 2 : 1)
                if detailed {
                    Text("約\(item.minutes)分・\(item.goalTitle)")
                        .font(GameFont.caption(10))
                        .foregroundStyle(GameColor.inkSoft)
                        .lineLimit(1)
                }
            }
            Spacer(minLength: 0)
        }
        .contentShape(Rectangle())
    }
}
