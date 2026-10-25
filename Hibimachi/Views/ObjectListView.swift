import HibimachiCore
import SwiftUI

/// Accessible alternative to tapping on the map: every object is a row that can be selected, moved or put away.
struct ObjectListView: View {
    let store: GameStore
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List {
                ForEach(store.world.objects) { object in
                    Button {
                        store.select(object.id)
                        dismiss()
                    } label: {
                        HStack {
                            Label(object.kind.displayName, systemImage: object.kind.symbolName)
                            Spacer()
                            Text("横\(object.origin.x + 1)・縦\(object.origin.y + 1)")
                                .font(.footnote)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .foregroundStyle(.primary)
                    .accessibilityHint("選ぶと島の上で動かしたり、しまったりできます")
                    .accessibilityIdentifier("object-row-\(object.kind.rawValue)")
                    .swipeActions {
                        Button("しまう", role: .destructive) {
                            store.select(object.id)
                            store.removeSelection()
                        }
                    }
                }
            }
            .overlay {
                if store.world.objects.isEmpty {
                    ContentUnavailableView("何も置かれていません", systemImage: "leaf")
                }
            }
            .navigationTitle("島にあるもの")
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("閉じる") { dismiss() }
                }
            }
        }
    }
}
