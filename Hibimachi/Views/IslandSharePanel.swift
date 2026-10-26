import SwiftUI
import UIKit

/// What gets shared: the island on a sky background with the game's name. Built only from the island
/// picture, so goals, quests, notes and photos can never end up in it.
struct IslandShareCard: View {
    let island: CGImage

    var body: some View {
        VStack(spacing: 10) {
            Image(decorative: island, scale: 1)
                .interpolation(.none)
                .resizable()
                .scaledToFit()
            Text("ひびまち")
                .font(GameFont.title(22))
                .foregroundStyle(GameColor.ink)
        }
        .padding(24)
        .frame(width: 360)
        .background(
            LinearGradient(colors: [GameColor.sky.opacity(0.5), GameColor.sky], startPoint: .top, endPoint: .bottom)
        )
        .environment(\.colorScheme, .light)
    }

    /// Renders the card at 3x (1080px wide). `nil` when there is no island picture yet.
    @MainActor
    static func render(_ island: CGImage?) -> UIImage? {
        guard let island else { return nil }
        let renderer = ImageRenderer(content: IslandShareCard(island: island))
        renderer.scale = 3
        return renderer.uiImage
    }
}

/// "島の絵をシェア": preview and the system share sheet.
struct IslandSharePanel: View {
    let picture: UIImage?
    let close: () -> Void

    var body: some View {
        GamePanel(title: "島の絵をシェア", symbol: "square.and.arrow.up", identifier: "share-panel", close: close) {
            VStack(spacing: 12) {
                if let picture {
                    Image(uiImage: picture)
                        .resizable()
                        .scaledToFit()
                        .clipShape(RoundedRectangle(cornerRadius: 16))
                        .overlay(RoundedRectangle(cornerRadius: 16).stroke(GameColor.line, lineWidth: 2))
                        .accessibilityLabel("ひびまちの島")
                    Label("島の絵だけをシェアします。目標や記録、写真は含まれません。", systemImage: "lock.fill")
                        .font(GameFont.caption())
                        .foregroundStyle(GameColor.inkSoft)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    ShareLink(
                        item: Image(uiImage: picture),
                        preview: SharePreview(Text("ひびまちの島"), image: Image(uiImage: picture))
                    ) {
                        Label("シェアする", systemImage: "square.and.arrow.up").frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.game)
                    .accessibilityIdentifier("share-island-link")
                } else {
                    Text("島の絵を用意できませんでした。島を表示してから、もう一度ためしてください。")
                        .font(GameFont.body(14, weight: .medium))
                        .foregroundStyle(GameColor.inkSoft)
                }
            }
        }
    }
}
