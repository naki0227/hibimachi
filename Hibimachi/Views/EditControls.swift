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

    /// "×2" when owned copies are in storage, otherwise the price in きらめき.
    private func costLabel(_ kind: ObjectKind) -> String {
        let stock = store.available(kind)
        return stock > 0 ? "×\(stock)" : "✨\(RewardRule.price(of: kind))"
    }

    private func accessibilityLabel(_ kind: ObjectKind) -> String {
        let stock = store.available(kind)
        if stock > 0 { return "\(kind.displayName)を置く（手持ち\(stock)）" }
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

/// Shown while placing or moving: live validity, fine-grained nudging and an explicit confirm.
struct EditBar: View {
    let store: GameStore

    private var isMoving: Bool {
        if case .moving = store.mode { true } else { false }
    }

    /// Shows the price when confirming will buy a new one (nothing is spent until then).
    private var confirmTitle: String {
        if isMoving { return "ここへ動かす" }
        if let kind = store.previewKind, store.available(kind) == 0 {
            return "✨\(RewardRule.price(of: kind))で置く"
        }
        return "ここに置く"
    }

    var body: some View {
        let issue = store.previewIssue
        VStack(spacing: 8) {
            StatusLine(
                ok: issue == nil,
                text: issue?.message ?? "ここに置けます（ドラッグかタップで場所を変えられます）")
            HStack(alignment: .center, spacing: 12) {
                NudgePad(store: store)
                VStack(spacing: 8) {
                    Button {
                        store.confirmPreview()
                    } label: {
                        Text(confirmTitle).frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.game)
                    .disabled(issue != nil)
                    .accessibilityIdentifier("confirm-edit")
                    Button(role: .cancel) {
                        store.cancelEdit()
                    } label: {
                        Text("やめる").frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.game(.secondary))
                    .accessibilityIdentifier("cancel-edit")
                }
            }
        }
        .gameBar()
    }
}

/// Path painting: tap tiles on the island; every tap can be undone.
struct PathBar: View {
    let store: GameStore

    var body: some View {
        VStack(spacing: 8) {
            StatusLine(
                ok: store.lastRejection == nil,
                text: store.lastRejection?.message ?? "タップした地面が小道になります（もう一度で草地に戻る）")
            HStack(spacing: 12) {
                UndoButton(store: store)
                Button {
                    store.cancelEdit()
                } label: {
                    Text("できた").frame(maxWidth: .infinity)
                }
                .buttonStyle(.game)
                .accessibilityIdentifier("finish-path")
            }
        }
        .gameBar()
    }
}

struct StatusLine: View {
    let ok: Bool
    let text: String

    var body: some View {
        HStack {
            Image(systemName: ok ? "checkmark.circle.fill" : "xmark.octagon.fill")
                .foregroundStyle(ok ? GameColor.leaf : GameColor.berry)
            Text(text)
                .font(GameFont.body(13))
                .foregroundStyle(GameColor.ink)
                .fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 0)
        }
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("placement-status")
    }
}

/// Arrow buttons: precise placement on small screens and a non-gesture path for VoiceOver / Switch Control.
/// Directions follow the isometric screen: ↑ moves away from the viewer (+x, +y diagonal is split per axis).
struct NudgePad: View {
    let store: GameStore

    var body: some View {
        HStack(spacing: 2) {
            arrow("arrow.down.left", "左下へ", dx: -1, dy: 0)
            VStack(spacing: 2) {
                arrow("arrow.up.left", "左上へ", dx: 0, dy: 1)
                arrow("arrow.down.right", "右下へ", dx: 0, dy: -1)
            }
            arrow("arrow.up.right", "右上へ", dx: 1, dy: 0)
        }
    }

    private func arrow(_ symbol: String, _ label: String, dx: Int, dy: Int) -> some View {
        Button {
            store.nudgePreview(dx: dx, dy: dy)
        } label: {
            Image(systemName: symbol)
                .font(.system(size: 16, weight: .heavy))
                .foregroundStyle(GameColor.ink)
                .frame(width: 44, height: 44)
                .gameTile(radius: 12)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(label)
    }
}

/// Shown when an object is selected in browse mode.
struct SelectionBar: View {
    let store: GameStore
    let object: WorldObject

    var body: some View {
        HStack(spacing: 6) {
            Text(object.kind.displayName)
                .font(GameFont.body(17, weight: .heavy))
                .foregroundStyle(GameColor.ink)
                .lineLimit(1)
                .minimumScaleFactor(0.6)
                .layoutPriority(1)
                .accessibilityIdentifier("selection-name")
            Spacer(minLength: 4)
            action("動かす", "arrow.up.and.down.and.arrow.left.and.right", "move-selection") {
                store.beginMovingSelection()
            }
            action("しまう", "archivebox", "remove-selection") { store.removeSelection() }
            action("とじる", "xmark", "deselect") { store.select(nil) }
            UndoButton(store: store)
        }
        .gameBar()
    }

    private func action(_ title: String, _ symbol: String, _ id: String, run: @escaping () -> Void) -> some View {
        Button(action: run) {
            VStack(spacing: 2) {
                Image(systemName: symbol).font(.system(size: 16, weight: .heavy))
                Text(title).font(GameFont.body(11, weight: .bold)).lineLimit(1).fixedSize()
            }
            .foregroundStyle(GameColor.ink)
            .frame(width: 48, height: 52)
            .gameTile(radius: 14)
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier(id)
    }
}
