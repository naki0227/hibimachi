import HibimachiCore
import SwiftUI

/// "この家を建てた日" (GAME-DESIGN P2): the day an object was placed, with what else happened that day.
struct BuildingMemoryPanel: View {
    let store: GameStore
    let objectID: UUID
    let close: () -> Void

    var body: some View {
        GamePanel(title: "思い出", symbol: "book.pages.fill", identifier: "memory-panel", close: close) {
            VStack(spacing: 12) {
                if let object = store.world.object(withID: objectID), let day = store.placedDay(of: object) {
                    HStack(spacing: 12) {
                        Image(decorative: IslandArt.sprite(for: object.kind).image, scale: 1)
                            .interpolation(.none).resizable().scaledToFit()
                            .frame(width: 56, height: 56)
                        Text("\(day.displayTitle)に\n\(object.kind.displayName)を迎えた日")
                            .font(GameFont.body(16, weight: .heavy))
                            .foregroundStyle(GameColor.ink)
                            .fixedSize(horizontal: false, vertical: true)
                        Spacer(minLength: 0)
                    }
                    .gameCard(highlighted: true)
                    if let history = store.albumDays.first(where: { $0.day == day }) {
                        AlbumDayCard(day: history, store: store)
                    }
                } else {
                    Text("この記録は見つかりませんでした。").font(GameFont.body(14)).foregroundStyle(GameColor.inkSoft)
                }
            }
        }
    }
}
