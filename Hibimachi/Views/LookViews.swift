import HibimachiCore
import SpriteKit
import SwiftUI

/// The player's favorite color (ADR-0017): residents' ribbons and the flags on goal towers. A device setting,
/// not game data. `.none` keeps the original look.
enum FavoriteColor: String, CaseIterable, Identifiable {
    case none
    case red
    case orange
    case yellow
    case green
    case blue
    case purple
    case pink

    var id: String { rawValue }

    var hex: UInt32? {
        switch self {
        case .none: nil
        case .red: 0xE5544B
        case .orange: 0xF2934A
        case .yellow: 0xF5CD47
        case .green: 0x5DB56A
        case .blue: 0x4A90D9
        case .purple: 0x9B72CF
        case .pink: 0xF07FA8
        }
    }

    var color: SKColor? { hex.map { SKColor(hex: $0) } }

    var title: LocalizedStringKey {
        switch self {
        case .none: LocalizedStringKey("なし")
        case .red: LocalizedStringKey("あか")
        case .orange: LocalizedStringKey("だいだい")
        case .yellow: LocalizedStringKey("きいろ")
        case .green: LocalizedStringKey("みどり")
        case .blue: LocalizedStringKey("あお")
        case .purple: LocalizedStringKey("むらさき")
        case .pink: LocalizedStringKey("ピンク")
        }
    }
}

/// "見た目" in settings: the favorite color, and what the island has been leaning towards lately.
struct LookSettingsCard: View {
    @Binding var favorite: FavoriteColor
    let mood: GoalCategory?

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Label("すきな色", systemImage: "paintpalette.fill")
                .font(GameFont.body(15, weight: .bold))
                .foregroundStyle(GameColor.ink)
            HStack(spacing: 6) {
                ForEach(FavoriteColor.allCases) { choice in
                    Button {
                        favorite = choice
                    } label: {
                        Circle()
                            .fill(choice.color.map { Color(uiColor: $0) } ?? GameColor.cream)
                            .overlay {
                                if choice == .none {
                                    Image(systemName: "slash.circle").foregroundStyle(GameColor.inkSoft)
                                }
                            }
                            .overlay(
                                Circle().stroke(
                                    choice == favorite ? GameColor.ink : GameColor.line,
                                    lineWidth: choice == favorite ? 3 : 1.5)
                            )
                            .frame(width: 32, height: 32)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(choice.title)
                    .accessibilityAddTraits(choice == favorite ? .isSelected : [])
                    .accessibilityIdentifier("favorite-\(choice.rawValue)")
                }
            }
            Text("住人のリボンと、目標の塔の旗がこの色になります。")
                .font(GameFont.caption(11)).foregroundStyle(GameColor.inkSoft)
                .fixedSize(horizontal: false, vertical: true)
            Text(moodText)
                .font(GameFont.caption(11)).foregroundStyle(GameColor.inkSoft)
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityIdentifier("island-mood")
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .gameCard()
    }

    private var moodText: String {
        guard let mood else {
            return String(localized: "島の雰囲気は、最近よくやっていることで少しずつ変わります（回数を数えるだけです）。")
        }
        return String(localized: "最近は「\(mood.title)」が多めの島。島の上に、その色の光が舞っています。")
    }
}

/// "塔が1段のびた！": a goal step was just finished (ADR-0017). Dismisses itself after a few seconds.
struct StepFinishedCard: View {
    let finish: StepFinished
    let dismiss: () -> Void

    var body: some View {
        Button(action: dismiss) {
            HStack(spacing: 12) {
                Image(systemName: finish.completesGoal ? "flag.checkered" : "building.columns.fill")
                    .font(.system(size: 26, weight: .bold))
                    .foregroundStyle(.white)
                    .frame(width: 64, height: 64)
                    .background(GameColor.wood, in: RoundedRectangle(cornerRadius: 14))
                    .overlay(RoundedRectangle(cornerRadius: 14).stroke(GameColor.line, lineWidth: 2))
                VStack(alignment: .leading, spacing: 2) {
                    Text(
                        finish.completesGoal
                            ? LocalizedStringKey("「\(finish.goalTitle)」の塔ができた！")
                            : LocalizedStringKey("「\(finish.goalTitle)」の塔が1段のびた！")
                    )
                    .font(GameFont.body(15, weight: .heavy)).foregroundStyle(GameColor.ink)
                    .fixedSize(horizontal: false, vertical: true)
                    Text("ステップ「\(finish.stepTitle)」を終えました。まわりの小島を見てみよう。")
                        .font(GameFont.caption(11)).foregroundStyle(GameColor.inkSoft)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer(minLength: 0)
            }
            .padding(10)
            .background(GameColor.paper, in: RoundedRectangle(cornerRadius: 20))
            .overlay(RoundedRectangle(cornerRadius: 20).stroke(GameColor.line, lineWidth: 2.5))
            .shadow(color: GameColor.ink.opacity(0.2), radius: 6, y: 3)
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .combine)
        .accessibilityHint("タップで閉じます")
        .accessibilityIdentifier("step-finished-card")
        .task {
            try? await Task.sleep(for: .seconds(6))
            dismiss()
        }
    }
}
