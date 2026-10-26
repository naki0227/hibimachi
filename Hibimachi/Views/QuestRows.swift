import HibimachiCore
import SwiftUI

struct ProgressSummary: View {
    let progress: PlayerProgress

    var body: some View {
        let xpInLevel = progress.totalXP % RewardRule.xpPerLevel
        let fraction = Double(xpInLevel) / Double(RewardRule.xpPerLevel)
        HStack(spacing: 14) {
            VStack(alignment: .leading, spacing: 6) {
                Text("Lv \(progress.level)").font(GameFont.title(24)).foregroundStyle(GameColor.ink)
                Capsule()
                    .fill(GameColor.cream)
                    .overlay(alignment: .leading) {
                        GeometryReader { proxy in
                            Capsule().fill(GameColor.leaf)
                                .frame(width: max(12, proxy.size.width * fraction))
                        }
                    }
                    .overlay(Capsule().stroke(GameColor.line, lineWidth: 2))
                    .frame(height: 14)
                Text("次のレベルまで \(RewardRule.xpPerLevel - xpInLevel) XP")
                    .font(GameFont.caption())
                    .foregroundStyle(GameColor.inkSoft)
            }
            VStack(spacing: 2) {
                Image(systemName: "sparkles").font(.system(size: 18, weight: .bold)).foregroundStyle(GameColor.sun)
                Text("\(progress.sparkles)").font(GameFont.title(20)).monospacedDigit().foregroundStyle(GameColor.ink)
                Text("きらめき").font(GameFont.caption(11)).foregroundStyle(GameColor.inkSoft)
            }
            .frame(width: 76, height: 76)
            .background(GameColor.cream, in: RoundedRectangle(cornerRadius: 18))
        }
        .gameCard()
        .accessibilityElement(children: .combine)
    }
}

struct RewardBanner: View {
    let reward: RewardTransaction
    let undo: () -> Void

    var body: some View {
        HStack {
            Label("+\(reward.xpDelta) XP　✨+\(reward.sparkleDelta)", systemImage: "leaf.fill")
                .font(GameFont.body(17, weight: .heavy))
                .foregroundStyle(GameColor.leafDark)
                // Identifier on the text only: on the row it would be inherited by the button below.
                .accessibilityIdentifier("reward-banner")
            Spacer()
            Button("取り消す", action: undo)
                .buttonStyle(.game(.secondary, compact: true))
                .accessibilityIdentifier("undo-completion")
        }
        .gameCard(highlighted: true)
    }
}

struct QuestRow: View {
    let quest: QuestTemplate
    let goalTitle: String
    let index: Int
    let complete: () -> Void
    let skip: () -> Void

    var body: some View {
        HStack(spacing: 8) {
            VStack(alignment: .leading, spacing: 2) {
                Text(quest.title).font(GameFont.body(16, weight: .bold)).foregroundStyle(GameColor.ink)
                Text("\(goalTitle)・約\(quest.minutes)分").font(GameFont.caption()).foregroundStyle(GameColor.inkSoft)
            }
            Spacer(minLength: 4)
            Button("ほかの", action: skip)
                .buttonStyle(.game(.secondary, compact: true))
                .accessibilityLabel("ほかのクエストにする")
            Button("やった！", action: complete)
                .buttonStyle(.game(.primary, compact: true))
                .accessibilityIdentifier("quest-done-\(index)")
        }
        .gameCard()
    }
}

/// Goal card that opens to show its quests, a field for the player's own quest and "おやすみ" (archive).
struct GoalRow: View {
    let goal: Goal
    let quests: [QuestTemplate]
    let addQuest: (String, Int) -> Bool
    let rest: () -> Void
    @State private var expanded = false
    @State private var draft = ""
    @State private var minutes = 5

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Button {
                withAnimation(.easeOut(duration: 0.2)) { expanded.toggle() }
            } label: {
                HStack {
                    Label(goal.title, systemImage: goal.category.symbolName)
                        .font(GameFont.body(16, weight: .bold))
                        .foregroundStyle(GameColor.ink)
                    Spacer()
                    Image(systemName: "chevron.down")
                        .font(.system(size: 13, weight: .heavy))
                        .foregroundStyle(GameColor.inkSoft)
                        .rotationEffect(.degrees(expanded ? 180 : 0))
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityValue(expanded ? "ひらいています" : "とじています")
            if expanded { details }
        }
        .gameCard()
    }

    @ViewBuilder
    private var details: some View {
        ForEach(quests) { quest in
            Text("・\(quest.title)（\(quest.minutes)分）")
                .font(GameFont.body(14, weight: .medium))
                .foregroundStyle(GameColor.inkSoft)
        }
        GameTextField(placeholder: "自分のクエストを追加", text: $draft)
        HStack(spacing: 8) {
            Button {
                minutes = max(1, minutes - 5)
            } label: {
                Image(systemName: "minus")
            }
            .buttonStyle(.game(.secondary, compact: true))
            .accessibilityLabel("時間を減らす")
            Text("\(minutes)分").font(GameFont.body(15, weight: .bold)).monospacedDigit().frame(minWidth: 44)
            Button {
                minutes = min(60, minutes + 5)
            } label: {
                Image(systemName: "plus")
            }
            .buttonStyle(.game(.secondary, compact: true))
            .accessibilityLabel("時間を増やす")
            Spacer()
            Button("追加") { if addQuest(draft, minutes) { draft = "" } }
                .buttonStyle(.game(.primary, compact: true))
                .disabled(draft.trimmingCharacters(in: .whitespaces).isEmpty)
        }
        Button("この目標をおやすみする", action: rest)
            .buttonStyle(.game(.secondary, compact: true))
    }
}
