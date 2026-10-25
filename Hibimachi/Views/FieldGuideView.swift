import HibimachiCore
import SwiftUI

/// Discovered reactions. Undiscovered ones are not listed (or counted) on purpose: finding them is the game.
struct FieldGuideView: View {
    let discoveries: Set<ReactionKind>
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List {
                if discoveries.isEmpty {
                    Text("まだ何も見つけていません。生き物のそばに、いろいろなものを置いてみましょう。")
                        .foregroundStyle(.secondary)
                }
                ForEach(ReactionKind.allCases.filter(discoveries.contains), id: \.self) { kind in
                    VStack(alignment: .leading, spacing: 4) {
                        Text(kind.title).font(.headline)
                        Text(kind.detail).font(.subheadline).foregroundStyle(.secondary)
                    }
                    .padding(.vertical, 4)
                    .accessibilityElement(children: .combine)
                }
                if !discoveries.isEmpty && discoveries.count < ReactionKind.allCases.count {
                    Text("置き方しだいで、まだ見たことのない姿が見られるかも…")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }
            .navigationTitle("図鑑")
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("閉じる") { dismiss() }
                }
            }
        }
        .accessibilityIdentifier("field-guide-sheet")
    }
}
