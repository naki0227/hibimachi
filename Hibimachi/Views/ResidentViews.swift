import HibimachiCore
import SwiftUI

/// Card for news about a resident: someone moved in ("新しい住人！") or became closer ("なかよし").
/// Same slot and behaviour as the discovery card: tap or wait to dismiss.
struct ResidentCard: View {
    let species: Species
    let badge: String
    let headline: String
    let line: String
    let identifier: String
    let dismiss: () -> Void

    static func arrival(_ species: Species, dismiss: @escaping () -> Void) -> ResidentCard {
        ResidentCard(
            species: species, badge: String(localized: "新しい住人！"),
            headline: String(localized: "\(species.displayName)がやってきた"), line: species.arrivalLine,
            identifier: "arrival-card", dismiss: dismiss)
    }

    static func friendship(_ notice: FriendshipNotice, dismiss: @escaping () -> Void) -> ResidentCard {
        ResidentCard(
            species: notice.species, badge: notice.level.title,
            headline: String(localized: "\(notice.species.displayName)と\(notice.level.title)になった"),
            line: notice.level.line, identifier: "friendship-card", dismiss: dismiss)
    }

    var body: some View {
        Button(action: dismiss) {
            HStack(spacing: 12) {
                Image(decorative: IslandArt.creatureImage(species), scale: 1)
                    .interpolation(.none)
                    .resizable()
                    .scaledToFit()
                    .padding(8)
                    .frame(width: 64, height: 64)
                    .background(GameColor.leafPale)
                    .clipShape(RoundedRectangle(cornerRadius: 14))
                    .overlay(RoundedRectangle(cornerRadius: 14).stroke(GameColor.line, lineWidth: 2))
                VStack(alignment: .leading, spacing: 2) {
                    Text(badge)
                        .font(GameFont.body(12, weight: .heavy)).foregroundStyle(.white)
                        .padding(.horizontal, 8).padding(.vertical, 2)
                        .background(GameColor.leaf, in: Capsule())
                    Text(headline).font(GameFont.body(16, weight: .heavy))
                        .foregroundStyle(GameColor.ink)
                    Text(line).font(GameFont.caption(11)).foregroundStyle(GameColor.inkSoft)
                }
                Spacer(minLength: 0)
            }
            .padding(10)
            .background(GameColor.paper, in: RoundedRectangle(cornerRadius: 20))
            .overlay(RoundedRectangle(cornerRadius: 20).stroke(GameColor.line, lineWidth: 2.5))
            .shadow(color: GameColor.ink.opacity(0.2), radius: 6, y: 3)
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(badge) \(headline)")
        .accessibilityHint("タップで閉じます")
        .accessibilityIdentifier(identifier)
        .task(id: "\(identifier)-\(species.rawValue)") {
            try? await Task.sleep(for: .seconds(6))
            dismiss()
        }
    }
}

/// "島が広がった！" when the island grows (ADR-0014). Same slot and behaviour as the other cards.
struct GrowthCard: View {
    let dismiss: () -> Void

    var body: some View {
        Button(action: dismiss) {
            HStack(spacing: 12) {
                Image(systemName: "leaf.fill")
                    .font(.system(size: 26, weight: .bold))
                    .foregroundStyle(.white)
                    .frame(width: 64, height: 64)
                    .background(GameColor.leaf, in: RoundedRectangle(cornerRadius: 14))
                    .overlay(RoundedRectangle(cornerRadius: 14).stroke(GameColor.line, lineWidth: 2))
                VStack(alignment: .leading, spacing: 2) {
                    Text("島が広がった！").font(GameFont.body(16, weight: .heavy)).foregroundStyle(GameColor.ink)
                    Text("まわりの海に、新しい土地ができました。")
                        .font(GameFont.caption(11)).foregroundStyle(GameColor.inkSoft)
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
        .accessibilityIdentifier("growth-card")
        .task {
            try? await Task.sleep(for: .seconds(6))
            dismiss()
        }
    }
}

/// Three hearts filled by friendship level, for the field guide.
struct FriendshipHearts: View {
    let friendship: Friendship

    var body: some View {
        HStack(spacing: 1) {
            ForEach(0..<3) { index in
                Image(systemName: index <= friendship.level.rawValue ? "heart.fill" : "heart")
                    .font(.system(size: 9, weight: .bold))
                    .foregroundStyle(index <= friendship.level.rawValue ? GameColor.berry : GameColor.inkSoft)
            }
        }
        .accessibilityElement()
        .accessibilityLabel(friendship.level.title)
    }
}

extension Friendship.Level {
    var title: String {
        switch self {
        case .new: String(localized: "はじめまして")
        case .friend: String(localized: "なかよし")
        case .bestFriend: String(localized: "だいすき")
        }
    }

    /// One line for the friendship card.
    var line: String {
        switch self {
        case .new: String(localized: "タップすると、なでられます。")
        case .friend: String(localized: "ときどき、うれしそうにはねるようになった。")
        case .bestFriend: String(localized: "いつもうれしそう。ハートを見せてくれる。")
        }
    }
}
