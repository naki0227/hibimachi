#if DEBUG
    import HibimachiCore
    import SwiftUI
    import WidgetKit

    /// Debug-only: the home-screen widget rendered with live data, in the three sizes. The real home screen
    /// cannot be screenshotted from UI tests, so this is how CI shows what the widget looks like.
    struct WidgetPreviewPanel: View {
        let store: GameStore
        let scene: IslandScene
        let close: () -> Void
        @State private var island: CGImage?

        var body: some View {
            let entry = IslandWidgetEntry(
                date: Date(), board: QuestBoard.make(progress: store.progress, day: store.today), island: island,
                placedCount: store.world.objects.count, discoveryCount: store.world.discoveries.count)
            GamePanel(title: "ウィジェット", symbol: "square.grid.2x2", identifier: "widget-preview", close: close) {
                VStack(spacing: 14) {
                    preview(entry, .systemLarge, CGSize(width: 320, height: 336))
                    preview(entry, .systemMedium, CGSize(width: 320, height: 150))
                    preview(entry, .systemSmall, CGSize(width: 150, height: 150))
                }
            }
            .onAppear { island = scene.islandPicture() }
        }

        private func preview(_ entry: IslandWidgetEntry, _ family: WidgetFamily, _ size: CGSize) -> some View {
            IslandWidgetView(entry: entry, family: family)
                .padding(14)
                .frame(width: size.width, height: size.height)
                .background(IslandWidgetBackground())
                .clipShape(RoundedRectangle(cornerRadius: 24))
                .shadow(color: GameColor.ink.opacity(0.2), radius: 6, y: 3)
        }
    }
#endif
