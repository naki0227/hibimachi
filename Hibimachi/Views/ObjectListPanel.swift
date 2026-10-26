import HibimachiCore
import SwiftUI

/// Accessible alternative to tapping on the map: every object is a row that can be selected or put away.
struct ObjectListPanel: View {
    let store: GameStore
    let close: () -> Void

    var body: some View {
        GamePanel(title: "島にあるもの", symbol: "list.bullet", identifier: "object-list-panel", close: close) {
            VStack(spacing: 8) {
                if store.world.objects.isEmpty {
                    Label("何も置かれていません", systemImage: "leaf")
                        .font(GameFont.body(15))
                        .foregroundStyle(GameColor.inkSoft)
                        .gameCard()
                }
                ForEach(store.world.objects) { object in
                    row(object)
                }
            }
        }
    }

    private func row(_ object: WorldObject) -> some View {
        HStack(spacing: 10) {
            Button {
                store.select(object.id)
                close()
            } label: {
                HStack(spacing: 10) {
                    Image(decorative: IslandArt.sprite(for: object.kind).image, scale: 1)
                        .interpolation(.none)
                        .resizable()
                        .scaledToFit()
                        .frame(width: 40, height: 40)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(object.kind.displayName).font(GameFont.body(16, weight: .bold))
                        Text("横\(object.origin.x + 1)・縦\(object.origin.y + 1)")
                            .font(GameFont.caption())
                            .foregroundStyle(GameColor.inkSoft)
                    }
                    Spacer(minLength: 0)
                }
                .foregroundStyle(GameColor.ink)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityHint("選ぶと島の上で動かしたり、しまったりできます")
            .accessibilityIdentifier("object-row-\(object.kind.rawValue)")
            Button("しまう") {
                store.select(object.id)
                store.removeSelection()
            }
            .buttonStyle(.game(.secondary, compact: true))
            .accessibilityLabel("\(object.kind.displayName)をしまう")
        }
        .gameCard()
    }
}
