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
    /// "今からやる" (nil while another quest is in progress).
    var start: (() -> Void)?

    var body: some View {
        // Title on its own line so long quest names are not squeezed by the buttons (device feedback 2026-10-27).
        VStack(alignment: .leading, spacing: 8) {
            VStack(alignment: .leading, spacing: 2) {
                Text(quest.title).font(GameFont.body(16, weight: .bold)).foregroundStyle(GameColor.ink)
                Text("\(goalTitle)・約\(quest.minutes)分").font(GameFont.caption()).foregroundStyle(GameColor.inkSoft)
            }
            HStack(spacing: 8) {
                Button("ほかの", action: skip)
                    .buttonStyle(.game(.secondary, compact: true))
                    .accessibilityLabel("ほかのクエストにする")
                Spacer(minLength: 0)
                if let start {
                    Button(action: start) {
                        Label("はじめる", systemImage: "play.fill")
                    }
                    .buttonStyle(.game(.secondary, compact: true))
                    .accessibilityLabel("今からやる")
                    .accessibilityIdentifier("quest-start-\(index)")
                }
                Button("やった！", action: complete)
                    .buttonStyle(.game(.primary, compact: true))
                    .accessibilityIdentifier("quest-done-\(index)")
            }
        }
        .gameCard()
    }
}
