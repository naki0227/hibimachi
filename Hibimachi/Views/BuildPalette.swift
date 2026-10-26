import HibimachiCore
import SwiftUI

/// Bottom palette in browse mode: category tabs, item cards with their pixel art, and undo.
struct BuildPalette: View {
    let store: GameStore
    @Binding var tab: PaletteTab

    var body: some View {
        VStack(spacing: 8) {
            HStack(spacing: 6) {
                ForEach(PaletteTab.allCases) { item in
                    Button {
                        tab = item
                    } label: {
                        Label(item.title, systemImage: item.symbolName)
                            .font(GameFont.body(13, weight: .heavy))
                            .lineLimit(1)
                            .minimumScaleFactor(0.8)
                            .frame(maxWidth: .infinity, minHeight: 36)
                            .background(tab == item ? GameColor.leaf : GameColor.cream, in: Capsule())
                            .foregroundStyle(tab == item ? Color.white : GameColor.inkSoft)
                    }
                    .buttonStyle(.plain)
                    .accessibilityAddTraits(tab == item ? .isSelected : [])
                    .accessibilityIdentifier("tab-\(item.rawValue)")
                }
            }
            HStack(spacing: 8) {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        if tab == .path {
                            PaletteCard(title: "小道をひく", identifier: "palette-path") {
                                Image(systemName: "road.lanes").font(.largeTitle).foregroundStyle(GameColor.wood)
                            } action: {
                                store.beginPaintingPath()
                            }
                        }
                        ForEach(tab.kinds, id: \.self) { kind in
                            PaletteCard(
                                title: kind.displayName, identifier: "palette-\(kind.rawValue)",
                                cost: costLabel(kind), enabled: store.canPlaceOrBuy(kind)
                            ) {
                                Image(decorative: IslandArt.sprite(for: kind).image, scale: 1)
                                    .interpolation(.none)
                                    .resizable()
                                    .scaledToFit()
                                    .saturation(isLocked(kind) ? 0 : 1)
                                    .overlay(alignment: .topTrailing) {
                                        if isLocked(kind) {
                                            Image(systemName: "lock.fill")
                                                .font(.system(size: 11, weight: .heavy))
                                                .foregroundStyle(GameColor.inkSoft)
                                        }
                                    }
                            } action: {
                                store.beginPlacing(kind)
                            }
                            .accessibilityLabel(accessibilityLabel(kind))
                        }
                    }
                    .padding(2)
                }
                UndoButton(store: store)
            }
        }
        .gameBar()
    }

    /// Not yet unlocked and none owned: shown greyed with what opens it.
    private func isLocked(_ kind: ObjectKind) -> Bool {
        store.available(kind) == 0 && !store.isUnlocked(kind)
    }

    /// "×2" when owned copies are in storage, the unlock condition while locked, otherwise the price.
    private func costLabel(_ kind: ObjectKind) -> String {
        let stock = store.available(kind)
        if stock > 0 { return "×\(stock)" }
        if isLocked(kind) { return kind.unlockHint }
        return "✨\(RewardRule.price(of: kind))"
    }

    private func accessibilityLabel(_ kind: ObjectKind) -> String {
        let stock = store.available(kind)
        if stock > 0 { return "\(kind.displayName)を置く（手持ち\(stock)）" }
        if isLocked(kind) {
            let requirement = Unlocks.requirement(for: kind)
            return "\(kind.displayName)（レベル\(requirement.level)か、発見\(requirement.discoveries)つで解放）"
        }
        let price = RewardRule.price(of: kind)
        return store.canPlaceOrBuy(kind)
            ? "\(kind.displayName)をきらめき\(price)で置く" : "\(kind.displayName)（きらめき\(price)が必要）"
    }
}

struct PaletteCard<Icon: View>: View {
    let title: String
    let identifier: String
    var cost: String?
    var enabled = true
    @ViewBuilder let icon: () -> Icon
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 2) {
                icon().frame(width: 48, height: 48)
                Text(title)
                    .font(GameFont.body(12, weight: .bold))
                    .foregroundStyle(GameColor.ink)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                if let cost {
                    Text(cost)
                        .font(GameFont.body(11, weight: .heavy))
                        .foregroundStyle(enabled ? GameColor.wood : GameColor.inkSoft)
                        .padding(.horizontal, 6)
                        .background(GameColor.cream, in: Capsule())
                }
            }
            .frame(width: 76, height: 94)
            .gameTile()
            .opacity(enabled ? 1 : 0.5)
        }
        .buttonStyle(.plain)
        .disabled(!enabled)
        .accessibilityIdentifier(identifier)
    }
}

struct UndoButton: View {
    let store: GameStore

    var body: some View {
        Button {
            store.undo()
        } label: {
            VStack(spacing: 2) {
                Image(systemName: "arrow.uturn.backward").font(.system(size: 18, weight: .heavy))
                Text("もどす").font(GameFont.body(11, weight: .bold))
            }
            .frame(width: 56, height: 60)
            .gameTile()
        }
        .buttonStyle(.plain)
        .foregroundStyle(store.canUndo ? GameColor.ink : GameColor.inkSoft.opacity(0.4))
        .disabled(!store.canUndo)
        .accessibilityLabel("ひとつ戻す")
        .accessibilityIdentifier("undo")
    }
}
