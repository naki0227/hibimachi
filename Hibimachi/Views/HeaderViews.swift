import HibimachiCore
import SwiftUI

/// Logo, small status chips and the menu (mockup header).
struct HeaderBar: View {
    let store: GameStore
    @Binding var confirmsReset: Bool
    @Binding var phaseOverride: DayPhase?
    let scene: IslandScene

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
            StatusChip(systemImage: "sparkles", text: "\(store.progress.sparkles)", tint: .yellow)
                .accessibilityLabel("きらめき \(store.progress.sparkles)")
                .accessibilityIdentifier("sparkle-balance")
            StatusChip(systemImage: "leaf.fill", text: "Lv\(store.progress.level)", tint: .green)
                .accessibilityLabel("レベル \(store.progress.level)")
                .accessibilityIdentifier("level")
            Menu {
                Button("島全体を表示", systemImage: "arrow.up.left.and.arrow.down.right") { scene.resetCamera() }
                Button("時間帯を端末の時刻に戻す", systemImage: "clock") { phaseOverride = nil }
                Button("島をはじめからにする", systemImage: "arrow.counterclockwise", role: .destructive) {
                    confirmsReset = true
                }
            } label: {
                Image(systemName: "line.3.horizontal")
                    .font(.headline)
                    .foregroundStyle(.white)
                    .frame(width: 44, height: 44)
                    .background(Color(red: 0.16, green: 0.33, blue: 0.47).opacity(0.75), in: Circle())
            }
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
        .font(.system(.subheadline, design: .rounded).weight(.bold))
        .foregroundStyle(.white)
        .padding(.horizontal, 10)
        .frame(minHeight: 34)
        .background(Color(red: 0.16, green: 0.33, blue: 0.47).opacity(0.75), in: Capsule())
        .accessibilityElement(children: .ignore)
    }
}

/// Round buttons on the right edge: today's quests, field guide, object list and time-of-day preview.
struct SideButtons: View {
    let phase: DayPhase
    let questsLeft: Int
    let objectCount: Int
    @Binding var showsQuests: Bool
    @Binding var showsFieldGuide: Bool
    @Binding var showsObjectList: Bool
    let cyclePhase: () -> Void

    var body: some View {
        VStack(spacing: 10) {
            RoundButton(
                systemImage: "checklist", label: "きょうのこと（のこり\(questsLeft)）", identifier: "quests",
                tint: .green
            ) {
                showsQuests = true
            }
            .overlay(alignment: .topTrailing) { Badge(text: questsLeft > 0 ? "\(questsLeft)" : nil) }
            RoundButton(systemImage: "book.closed.fill", label: "図鑑", identifier: "field-guide") {
                showsFieldGuide = true
            }
            RoundButton(systemImage: "list.bullet", label: "配置物の一覧", identifier: "object-list") {
                showsObjectList = true
            }
            .overlay(alignment: .topTrailing) {
                Badge(text: "\(objectCount)")
                    .accessibilityLabel("置いたもの \(objectCount)こ")
                    .accessibilityIdentifier("object-count")
            }
            RoundButton(
                systemImage: phase.symbolName, label: "時間帯: \(phase.title)（タップで切り替え）",
                identifier: "day-phase", tint: phase == .night ? .indigo : .orange, action: cyclePhase)
        }
    }
}

struct Badge: View {
    let text: String?

    var body: some View {
        if let text {
            Text(text)
                .font(.caption2.weight(.bold)).monospacedDigit()
                .foregroundStyle(.white)
                .padding(.horizontal, 5)
                .frame(minWidth: 18, minHeight: 18)
                .background(Color.orange, in: Capsule())
                .offset(x: 4, y: -4)
        }
    }
}

struct RoundButton: View {
    let systemImage: String
    let label: String
    let identifier: String
    var tint: Color = Color(red: 0.15, green: 0.22, blue: 0.28)
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: systemImage)
                .font(.title3)
                .foregroundStyle(tint)
                .frame(width: 48, height: 48)
                .background(.regularMaterial, in: Circle())
                .shadow(color: .black.opacity(0.12), radius: 4, y: 2)
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
                        Image(systemName: "sparkles").font(.title).foregroundStyle(.orange)
                    }
                }
                .frame(width: 64, height: 64)
                .background(Color(red: 0.56, green: 0.8, blue: 0.42).opacity(0.4))
                .clipShape(RoundedRectangle(cornerRadius: 12))
                VStack(alignment: .leading, spacing: 2) {
                    Label("発見！", systemImage: "leaf.fill")
                        .font(.caption.weight(.bold)).foregroundStyle(.orange)
                    Text(kind.title).font(.system(.headline, design: .rounded))
                    Text("島のくらしが、少し豊かになったようです。")
                        .font(.caption2).foregroundStyle(.secondary)
                }
                Spacer(minLength: 0)
                Image(systemName: "sparkle").foregroundStyle(.yellow)
            }
            .padding(10)
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 18))
            .shadow(color: .black.opacity(0.12), radius: 6, y: 3)
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
                .font(.footnote)
            Spacer()
            Button("再試行", action: retry)
                .frame(minHeight: 44)
        }
        .padding(.horizontal, 12)
        .background(.orange.opacity(0.25), in: RoundedRectangle(cornerRadius: 12))
        .accessibilityIdentifier("save-error")
    }
}
