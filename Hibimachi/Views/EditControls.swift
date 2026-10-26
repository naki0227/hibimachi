import HibimachiCore
import SwiftUI

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
    /// Opens the memory of the day this object was placed.
    let openMemory: () -> Void

    var body: some View {
        HStack(spacing: 6) {
            VStack(alignment: .leading, spacing: 2) {
                Text(object.kind.displayName)
                    .font(GameFont.body(17, weight: .heavy))
                    .foregroundStyle(GameColor.ink)
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)
                    .accessibilityIdentifier("selection-name")
                if let day = store.placedDay(of: object) {
                    Button(action: openMemory) {
                        Label("\(day.month)/\(day.day)に迎えた", systemImage: "book.pages")
                            .font(GameFont.body(11, weight: .bold))
                            .foregroundStyle(GameColor.leafDark)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("\(day.month)月\(day.day)日に迎えた。その日の思い出を見る")
                    .accessibilityIdentifier("selection-memory")
                } else {
                    Text("はじめからある").font(GameFont.caption(11)).foregroundStyle(GameColor.inkSoft)
                }
            }
            .layoutPriority(1)
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
