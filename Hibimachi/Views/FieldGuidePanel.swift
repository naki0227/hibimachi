import HibimachiCore
import SwiftUI

/// Discovered reactions. Undiscovered ones are not listed (or counted) on purpose: finding them is the game.
struct FieldGuidePanel: View {
    let discoveries: Set<ReactionKind>
    /// Snapshots taken this session; entries without one show an icon.
    var images: [ReactionKind: CGImage] = [:]
    let close: () -> Void

    var body: some View {
        GamePanel(title: "図鑑", symbol: "book.closed.fill", identifier: "field-guide-panel", close: close) {
            VStack(spacing: 10) {
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
