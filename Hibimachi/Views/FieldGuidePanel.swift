import HibimachiCore
import SwiftUI

/// Discovered reactions. Undiscovered ones are not listed (or counted) on purpose: finding them is the game.
struct FieldGuidePanel: View {
    let discoveries: Set<ReactionKind>
    /// Snapshots taken this session; entries without one show an icon.
    var images: [ReactionKind: CGImage] = [:]
    /// Who lives on the island now (newcomers appear as the island gets livelier).
    var residents: [Creature] = []
    let close: () -> Void

    var body: some View {
        GamePanel(title: "図鑑", symbol: "book.closed.fill", identifier: "field-guide-panel", close: close) {
            VStack(spacing: 10) {
                Text("島の住人").gameSectionTitle()
                HStack(spacing: 10) {
                    ForEach(residents, id: \.id) { resident in
                        VStack(spacing: 4) {
                            Image(decorative: IslandArt.creatureImage(resident.species), scale: 1)
                                .interpolation(.none).resizable().scaledToFit()
                                .frame(width: 44, height: 40)
                            Text(resident.species.displayName).font(GameFont.body(12, weight: .bold))
                                .foregroundStyle(GameColor.ink)
                            FriendshipHearts(friendship: resident.friendship)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8)
                        .background(.white, in: RoundedRectangle(cornerRadius: 14))
                        .overlay(RoundedRectangle(cornerRadius: 14).stroke(GameColor.line, lineWidth: 2))
                        .accessibilityElement(children: .combine)
                    }
                }
                Text("住人をタップすると、なでられます。なかよくなると…？")
                    .font(GameFont.caption(11))
                    .foregroundStyle(GameColor.inkSoft)
                    .frame(maxWidth: .infinity, alignment: .leading)
                Text("見つけた姿").gameSectionTitle()
                if discoveries.isEmpty {
                    Text("まだ何も見つけていません。生き物のそばに、いろいろなものを置いてみましょう。")
                        .font(GameFont.body(15, weight: .medium))
                        .foregroundStyle(GameColor.inkSoft)
                        .gameCard()
                }
                ForEach(ReactionKind.allCases.filter(discoveries.contains), id: \.self) { kind in
                    entry(kind)
                }
                if !discoveries.isEmpty && discoveries.count < ReactionKind.allCases.count {
                    Label("置き方しだいで、まだ見たことのない姿が見られるかも…", systemImage: "sparkle")
                        .font(GameFont.caption(13))
                        .foregroundStyle(GameColor.inkSoft)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
        }
    }

    private func entry(_ kind: ReactionKind) -> some View {
        HStack(spacing: 12) {
            Group {
                if let image = images[kind] {
                    Image(decorative: image, scale: 1).interpolation(.none).resizable().scaledToFill()
                } else {
                    Image(systemName: "leaf.fill").font(.title2).foregroundStyle(GameColor.leaf)
                }
            }
            .frame(width: 64, height: 64)
            .background(GameColor.leafPale)
            .clipShape(RoundedRectangle(cornerRadius: 14))
            .overlay(RoundedRectangle(cornerRadius: 14).stroke(GameColor.line, lineWidth: 2))
            VStack(alignment: .leading, spacing: 4) {
                Text(kind.title).font(GameFont.body(17, weight: .heavy)).foregroundStyle(GameColor.ink)
                Text(kind.detail).font(GameFont.body(13, weight: .medium)).foregroundStyle(GameColor.inkSoft)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .gameCard()
        .accessibilityElement(children: .combine)
    }
}
