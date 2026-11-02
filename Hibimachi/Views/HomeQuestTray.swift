import HibimachiCore
import SwiftUI

/// Today's quests on the island screen itself (owner feedback 2026-10-27: the app gamifies daily life, so the
/// day's tasks should be in view without opening a panel). Tap the circle when done, or "はじめる" to start one
/// with a record. Can be folded away to look at the island; goals and editing stay in the quests panel.
struct HomeQuestTray: View {
    let store: GameStore
    let openQuests: () -> Void
    @AppStorage("home.questTrayFolded") private var folded = false

    var body: some View {
        let quests = store.todaysQuests
        VStack(alignment: .leading, spacing: 8) {
            header(left: quests.count)
            if !folded {
                if store.progress.activeGoals.isEmpty {
                    Button(action: openQuests) {
                        Label("目標を決めて、きょうのクエストをもらう", systemImage: "sparkles")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.game(.primary, compact: true))
                    .accessibilityIdentifier("home-quests-setup")
                } else if quests.isEmpty {
                    Text("きょうのクエストはぜんぶできました！島でひと休みしよう。")
                        .font(GameFont.body(13, weight: .bold))
                        .foregroundStyle(GameColor.leafDark)
                        .fixedSize(horizontal: false, vertical: true)
                }
                ForEach(Array(quests.enumerated()), id: \.element.id) { index, quest in
                    row(quest, index: index)
                }
                if let last = store.lastCompletion {
                    HStack {
                        Label("+\(last.reward.xpDelta) XP　✨+\(last.reward.sparkleDelta)", systemImage: "leaf.fill")
                            .font(GameFont.body(13, weight: .heavy))
                            .foregroundStyle(GameColor.leafDark)
                            .accessibilityIdentifier("home-reward")
                        Spacer()
                        Button("取り消す") { store.undoLastCompletion() }
                            .buttonStyle(.game(.secondary, compact: true))
                            .accessibilityIdentifier("home-undo")
                    }
                }
            }
        }
        .padding(12)
        .gameBar()
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("home-quests")
    }

    private func header(left: Int) -> some View {
        Button {
            withAnimation(.easeOut(duration: 0.2)) { folded.toggle() }
        } label: {
            HStack(spacing: 6) {
                Label("きょうのクエスト", systemImage: "checklist")
                    .font(GameFont.body(14, weight: .heavy))
                    .foregroundStyle(GameColor.ink)
                if left > 0 {
                    Text("のこり\(left)").font(GameFont.caption(12)).foregroundStyle(GameColor.inkSoft)
                }
                Spacer()
                Image(systemName: "chevron.down")
                    .font(.system(size: 12, weight: .heavy))
                    .foregroundStyle(GameColor.inkSoft)
                    .rotationEffect(.degrees(folded ? 180 : 0))
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityValue(folded ? String(localized: "とじています") : String(localized: "ひらいています"))
        .accessibilityIdentifier("home-quests-toggle")
    }

    private func row(_ quest: QuestTemplate, index: Int) -> some View {
        HStack(spacing: 10) {
            Button {
                store.completeQuest(quest.id)
            } label: {
                Image(systemName: "circle")
                    .font(.system(size: 26, weight: .semibold))
                    .foregroundStyle(GameColor.leafDark)
                    .frame(width: 44, height: 44)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("\(quest.title)をやった")
            .accessibilityIdentifier("home-quest-done-\(index)")
            VStack(alignment: .leading, spacing: 1) {
                Text(quest.title)
                    .font(GameFont.body(14, weight: .bold))
                    .foregroundStyle(GameColor.ink)
                    .lineLimit(2)
                Text("約\(quest.minutes)分").font(GameFont.caption(11)).foregroundStyle(GameColor.inkSoft)
            }
            Spacer(minLength: 4)
            if store.activeSession == nil {
                Button {
                    if store.startTask(quest.id) { openQuests() }
                } label: {
                    Label("はじめる", systemImage: "play.fill")
                }
                .buttonStyle(.game(.secondary, compact: true))
                .accessibilityIdentifier("home-quest-start-\(index)")
            }
        }
    }
}
