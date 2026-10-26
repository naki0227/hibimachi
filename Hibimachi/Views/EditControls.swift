import HibimachiCore
import SwiftUI

/// Card style shared by the bottom panels (white, rounded, soft shadow as in the mockup).
private struct PanelBackground: ViewModifier {
    func body(content: Content) -> some View {
        content
            .padding(10)
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 22))
            .shadow(color: .black.opacity(0.12), radius: 8, y: 3)
    }
}

extension View {
    fileprivate func panel() -> some View { modifier(PanelBackground()) }
}

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
                            .font(.system(.footnote, design: .rounded).weight(.bold))
                            .lineLimit(1)
                            .frame(maxWidth: .infinity, minHeight: 36)
                            .background(
                                tab == item ? Color.white : Color.clear, in: RoundedRectangle(cornerRadius: 12)
                            )
                            .foregroundStyle(tab == item ? Color.green : Color.secondary)
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
                                Image(systemName: "road.lanes").font(.largeTitle).foregroundStyle(.brown)
                            } action: {
                                store.beginPaintingPath()
                            }
                        }
                        ForEach(tab.kinds, id: \.self) { kind in
                            PaletteCard(title: kind.displayName, identifier: "palette-\(kind.rawValue)") {
                                Image(decorative: IslandArt.sprite(for: kind).image, scale: 1)
                                    .interpolation(.none)
                                    .resizable()
                                    .scaledToFit()
                            } action: {
                                store.beginPlacing(kind)
                            }
                            .accessibilityLabel("\(kind.displayName)を置く")
                        }
                    }
                    .padding(2)
                }
                UndoButton(store: store)
            }
        }
        .panel()
    }
}

struct PaletteCard<Icon: View>: View {
    let title: String
    let identifier: String
    @ViewBuilder let icon: () -> Icon
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 4) {
                icon().frame(width: 52, height: 52)
                Text(title)
                    .font(.system(.caption, design: .rounded).weight(.semibold))
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
            }
            .frame(width: 76, height: 86)
            .background(Color.white.opacity(0.85), in: RoundedRectangle(cornerRadius: 16))
        }
        .buttonStyle(.plain)
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
                Image(systemName: "arrow.uturn.backward").font(.title3.weight(.semibold))
                Text("もどす").font(.system(.caption2, design: .rounded))
            }
            .frame(width: 56, height: 60)
            .background(Color.white.opacity(0.85), in: RoundedRectangle(cornerRadius: 16))
        }
        .buttonStyle(.plain)
        .foregroundStyle(store.canUndo ? Color.primary : Color.secondary.opacity(0.5))
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

    var body: some View {
        let issue = store.previewIssue
        VStack(spacing: 8) {
            StatusLine(
                ok: issue == nil,
                text: issue?.message ?? "ここに置けます（ドラッグかタップで場所を変えられます）")
            HStack(alignment: .center, spacing: 12) {
                NudgePad(store: store)
                VStack(spacing: 8) {
                    Button(isMoving ? "ここへ動かす" : "ここに置く") { store.confirmPreview() }
                        .buttonStyle(.borderedProminent)
                        .tint(.green)
                        .frame(maxWidth: .infinity, minHeight: 44)
                        .disabled(issue != nil)
                        .accessibilityIdentifier("confirm-edit")
                    Button("やめる", role: .cancel) { store.cancelEdit() }
                        .buttonStyle(.bordered)
                        .frame(maxWidth: .infinity, minHeight: 44)
                        .accessibilityIdentifier("cancel-edit")
                }
                .lineLimit(1)
                .minimumScaleFactor(0.8)
            }
        }
        .panel()
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
                Button("できた") { store.cancelEdit() }
                    .buttonStyle(.borderedProminent)
                    .tint(.green)
                    .frame(maxWidth: .infinity, minHeight: 44)
                    .accessibilityIdentifier("finish-path")
            }
        }
        .panel()
    }
}

struct StatusLine: View {
    let ok: Bool
    let text: String

    var body: some View {
        HStack {
            Image(systemName: ok ? "checkmark.circle.fill" : "xmark.octagon.fill")
                .foregroundStyle(ok ? Color.teal : Color.red)
            Text(text)
                .font(.footnote)
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
                .font(.body.weight(.semibold))
                .frame(width: 44, height: 44)
                .background(Color.white.opacity(0.85), in: RoundedRectangle(cornerRadius: 10))
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
                .font(.system(.headline, design: .rounded))
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
        .panel()
    }

    private func action(_ title: String, _ symbol: String, _ id: String, run: @escaping () -> Void) -> some View {
        Button(action: run) {
            VStack(spacing: 2) {
                Image(systemName: symbol).font(.body.weight(.semibold))
                Text(title).font(.system(.caption2, design: .rounded)).lineLimit(1).fixedSize()
            }
            .frame(width: 48, height: 52)
            .background(Color.white.opacity(0.85), in: RoundedRectangle(cornerRadius: 14))
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier(id)
    }
}
