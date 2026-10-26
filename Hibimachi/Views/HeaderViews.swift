import HibimachiCore
import SwiftUI

/// Logo, small status chips and the menu (mockup header).
struct HeaderBar: View {
    let store: GameStore
    let openMenu: () -> Void

    var body: some View {
        HStack(alignment: .center, spacing: 8) {
            VStack(alignment: .leading, spacing: 0) {
                Label("HIBIMACHI", systemImage: "leaf.fill")
                    .font(.system(.headline, design: .rounded).weight(.heavy))
                    .tracking(2)
                Text("小さな島に、日々が育つ")
                    .font(.system(.caption2, design: .rounded))
            }
            .foregroundStyle(.white)
            .shadow(color: .black.opacity(0.25), radius: 2, y: 1)
            .accessibilityElement(children: .combine)
            Spacer(minLength: 4)
            StatusChip(systemImage: "sparkles", text: "\(store.progress.sparkles)", tint: GameColor.sun)
                .accessibilityLabel("きらめき \(store.progress.sparkles)")
                .accessibilityIdentifier("sparkle-balance")
            StatusChip(systemImage: "leaf.fill", text: "Lv\(store.progress.level)", tint: GameColor.leaf)
                .accessibilityLabel("レベル \(store.progress.level)")
                .accessibilityIdentifier("level")
            Button(action: openMenu) {
                Image(systemName: "line.3.horizontal")
                    .font(.system(size: 17, weight: .heavy))
                    .foregroundStyle(GameColor.ink)
                    .frame(width: 44, height: 44)
                    .background(GameColor.paper, in: Circle())
                    .overlay(Circle().stroke(GameColor.line, lineWidth: 2.5))
                    .shadow(color: GameColor.ink.opacity(0.18), radius: 3, y: 2)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("メニュー")
        }
    }
}

struct StatusChip: View {
    let systemImage: String
    let text: String
    let tint: Color

    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: systemImage).foregroundStyle(tint)
            Text(text).monospacedDigit().contentTransition(.numericText())
        }
        .font(GameFont.body(15, weight: .heavy))
        .foregroundStyle(GameColor.ink)
        .padding(.horizontal, 11)
        .frame(minHeight: 34)
        .background(GameColor.paper, in: Capsule())
        .overlay(Capsule().stroke(GameColor.line, lineWidth: 2.5))
        .shadow(color: GameColor.ink.opacity(0.18), radius: 3, y: 2)
        .accessibilityElement(children: .ignore)
    }
}

/// Round buttons on the right edge: today's quests, field guide, object list and time-of-day preview.
struct SideButtons: View {
    let phase: DayPhase
    let questsLeft: Int
    let objectCount: Int
    /// The tutorial's quests step points here.
    var highlightsQuests = false
    let open: (IslandOverlay) -> Void
    let cyclePhase: () -> Void

    var body: some View {
        VStack(spacing: 10) {
            RoundButton(
                systemImage: "checklist", label: "きょうのこと（のこり\(questsLeft)）", identifier: "quests",
                tint: GameColor.leafDark
            ) {
                open(.quests)
            }
            .modifier(TutorialPulse(active: highlightsQuests))
            .overlay(alignment: .topTrailing) { Badge(text: questsLeft > 0 ? "\(questsLeft)" : nil) }
            RoundButton(systemImage: "book.closed.fill", label: "図鑑", identifier: "field-guide") {
                open(.fieldGuide)
            }
            RoundButton(systemImage: "list.bullet", label: "配置物の一覧", identifier: "object-list") {
                open(.objectList)
            }
            .overlay(alignment: .topTrailing) {
                Badge(text: "\(objectCount)")
                    .accessibilityLabel("置いたもの \(objectCount)こ")
                    .accessibilityIdentifier("object-count")
            }
            RoundButton(
                systemImage: phase.symbolName, label: "時間帯: \(phase.title)（タップで切り替え）",
                identifier: "day-phase", tint: phase == .night ? .indigo : GameColor.wood, action: cyclePhase)
        }
    }
}

struct Badge: View {
    let text: String?

    var body: some View {
        if let text {
            Text(text)
                .font(GameFont.body(11, weight: .heavy)).monospacedDigit()
                .foregroundStyle(.white)
                .padding(.horizontal, 5)
                .frame(minWidth: 20, minHeight: 20)
                .background(GameColor.berry, in: Capsule())
                .overlay(Capsule().stroke(.white, lineWidth: 2))
                .offset(x: 4, y: -4)
        }
    }
}

struct RoundButton: View {
    let systemImage: String
    let label: String
    let identifier: String
    var tint: Color = GameColor.ink
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: systemImage)
                .font(.system(size: 20, weight: .bold))
                .foregroundStyle(tint)
                .frame(width: 50, height: 50)
                .background(GameColor.paper, in: Circle())
                .overlay(Circle().stroke(GameColor.line, lineWidth: 2.5))
                .shadow(color: GameColor.ink.opacity(0.18), radius: 3, y: 2)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(label)
        .accessibilityIdentifier(identifier)
    }
}

/// "発見！" card with a snapshot of the moment (mockup).
struct DiscoveryCard: View {
    let kind: ReactionKind
    let image: CGImage?
    let dismiss: () -> Void

    var body: some View {
        Button(action: dismiss) {
            HStack(spacing: 12) {
                Group {
                    if let image {
                        Image(decorative: image, scale: 1).interpolation(.none).resizable().scaledToFill()
                    } else {
                        Image(systemName: "sparkles").font(.title).foregroundStyle(GameColor.sun)
                    }
                }
                .frame(width: 64, height: 64)
                .background(GameColor.leafPale)
                .clipShape(RoundedRectangle(cornerRadius: 14))
                .overlay(RoundedRectangle(cornerRadius: 14).stroke(GameColor.line, lineWidth: 2))
                VStack(alignment: .leading, spacing: 2) {
                    Text("発見！")
                        .font(GameFont.body(12, weight: .heavy)).foregroundStyle(.white)
                        .padding(.horizontal, 8).padding(.vertical, 2)
                        .background(GameColor.apricot, in: Capsule())
                    Text(kind.title).font(GameFont.body(16, weight: .heavy)).foregroundStyle(GameColor.ink)
                    Text("島のくらしが、少し豊かになったようです。")
                        .font(GameFont.caption(11)).foregroundStyle(GameColor.inkSoft)
                }
                Spacer(minLength: 0)
                Image(systemName: "sparkle").foregroundStyle(GameColor.sun)
            }
            .padding(10)
            .background(GameColor.paper, in: RoundedRectangle(cornerRadius: 20))
            .overlay(RoundedRectangle(cornerRadius: 20).stroke(GameColor.line, lineWidth: 2.5))
            .shadow(color: GameColor.ink.opacity(0.2), radius: 6, y: 3)
        }
        .buttonStyle(.plain)
        .accessibilityLabel("発見！ \(kind.title)")
        .accessibilityHint("タップで閉じます。図鑑に記録されました")
        .accessibilityIdentifier("discovery-toast")
        .task(id: kind) {
            try? await Task.sleep(for: .seconds(5))
            dismiss()
        }
    }
}

struct SaveErrorBanner: View {
    let message: String
    let retry: () -> Void

    var body: some View {
        HStack {
            Text("保存できませんでした。島はこのまま残っています。")
                .font(GameFont.body(13))
                .foregroundStyle(GameColor.ink)
            Spacer()
            Button("再試行", action: retry)
                .buttonStyle(.game(.primary, compact: true))
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(GameColor.paper, in: RoundedRectangle(cornerRadius: 16))
        .overlay(RoundedRectangle(cornerRadius: 16).stroke(GameColor.apricot, lineWidth: 2.5))
        .accessibilityIdentifier("save-error")
    }
}
