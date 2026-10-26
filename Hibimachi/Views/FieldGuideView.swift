import HibimachiCore
import SwiftUI

/// Discovered reactions. Undiscovered ones are not listed (or counted) on purpose: finding them is the game.
struct FieldGuideView: View {
    let discoveries: Set<ReactionKind>
    /// Snapshots taken this session; entries without one show an icon.
    var images: [ReactionKind: CGImage] = [:]
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List {
                if discoveries.isEmpty {
                    Text("まだ何も見つけていません。生き物のそばに、いろいろなものを置いてみましょう。")
                        .foregroundStyle(.secondary)
                }
                ForEach(ReactionKind.allCases.filter(discoveries.contains), id: \.self) { kind in
                    HStack(spacing: 12) {
                        Group {
                            if let image = images[kind] {
                                Image(decorative: image, scale: 1).interpolation(.none).resizable().scaledToFill()
                            } else {
                                Image(systemName: "leaf.fill").foregroundStyle(.green)
                            }
                        }
                        .frame(width: 56, height: 56)
                        .background(Color.green.opacity(0.12))
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                        VStack(alignment: .leading, spacing: 4) {
                            Text(kind.title).font(.system(.headline, design: .rounded))
                            Text(kind.detail).font(.subheadline).foregroundStyle(.secondary)
                        }
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
