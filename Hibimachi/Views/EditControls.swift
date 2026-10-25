import HibimachiCore
import SwiftUI

/// Bottom palette in browse mode: pick something to build, or undo the last edit.
struct BuildPalette: View {
    let store: GameStore

    var body: some View {
        HStack(spacing: 8) {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(ObjectKind.allCases, id: \.self) { kind in
                        Button {
                            store.beginPlacing(kind)
                        } label: {
                            VStack(spacing: 4) {
                                Image(systemName: kind.symbolName).font(.title3)
                                Text(kind.displayName).font(.caption2).lineLimit(1).minimumScaleFactor(0.7)
                            }
                            .frame(minWidth: 60, minHeight: 56)
                            .padding(.horizontal, 4)
                            .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 12))
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("\(kind.displayName)を置く")
                        .accessibilityIdentifier("palette-\(kind.rawValue)")
                    }
                }
                .padding(4)
            }
            UndoButton(store: store)
        }
        .padding(6)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 18))
    }
}

struct UndoButton: View {
    let store: GameStore

    var body: some View {
        Button {
            store.undo()
        } label: {
            Image(systemName: "arrow.uturn.backward")
                .font(.title3)
                .frame(width: 52, height: 56)
        }
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
            HStack {
                Image(systemName: issue == nil ? "checkmark.circle.fill" : "xmark.octagon.fill")
                    .foregroundStyle(issue == nil ? Color.teal : Color.red)
                Text(issue?.message ?? "ここに置けます（ドラッグかタップで場所を変えられます）")
                    .font(.footnote)
                    .fixedSize(horizontal: false, vertical: true)
                Spacer(minLength: 0)
            }
            .accessibilityElement(children: .combine)
            .accessibilityIdentifier("placement-status")

            HStack(alignment: .center, spacing: 12) {
                NudgePad(store: store)
                VStack(spacing: 8) {
                    Button(isMoving ? "ここへ動かす" : "ここに置く") { store.confirmPreview() }
                        .buttonStyle(.borderedProminent)
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
        .padding(12)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 18))
    }
}

/// Arrow buttons: precise placement on small screens and a non-gesture path for VoiceOver / Switch Control.
struct NudgePad: View {
    let store: GameStore

    var body: some View {
        HStack(spacing: 2) {
            arrow("arrow.left", "左へ", dx: -1, dy: 0)
            VStack(spacing: 2) {
                arrow("arrow.up", "上へ", dx: 0, dy: 1)
                arrow("arrow.down", "下へ", dx: 0, dy: -1)
            }
            arrow("arrow.right", "右へ", dx: 1, dy: 0)
        }
    }

    private func arrow(_ symbol: String, _ label: String, dx: Int, dy: Int) -> some View {
        Button {
            store.nudgePreview(dx: dx, dy: dy)
        } label: {
            Image(systemName: symbol)
                .font(.body.weight(.semibold))
                .frame(width: 44, height: 44)
                .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 10))
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
        HStack(spacing: 8) {
            Text(object.kind.displayName)
                .font(.headline)
                .accessibilityIdentifier("selection-name")
            Spacer()
            Button("動かす", systemImage: "arrow.up.and.down.and.arrow.left.and.right") {
                store.beginMovingSelection()
            }
            .buttonStyle(.bordered)
            .frame(minHeight: 44)
            .accessibilityIdentifier("move-selection")
            Button("しまう", systemImage: "trash", role: .destructive) {
                store.removeSelection()
            }
            .buttonStyle(.bordered)
            .frame(minHeight: 44)
            .accessibilityIdentifier("remove-selection")
            Button {
                store.select(nil)
            } label: {
                Image(systemName: "xmark").frame(width: 44, height: 44)
            }
            .accessibilityLabel("選択をやめる")
            UndoButton(store: store)
        }
        .labelStyle(.titleAndIcon)
        .padding(10)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 18))
    }
}
