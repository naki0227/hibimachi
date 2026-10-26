import HibimachiCore
import SwiftUI

/// A small photo from the album, loaded as a thumbnail off the stored JPEG.
struct PhotoThumb: View {
    let url: URL?
    var size: CGFloat = 64
    @State private var image: CGImage?

    var body: some View {
        Group {
            if let image {
                Image(decorative: image, scale: 1).resizable().scaledToFill()
            } else {
                GameColor.cream
            }
        }
        .frame(width: size, height: size)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .task(id: url) {
            guard let url else { return }
            // A 240px thumbnail of an already-downsized JPEG is cheap enough for the main actor.
            image = PhotoPrep.thumbnail(at: url)
        }
    }
}

/// "くらべる写真": choose an earlier photo to show next to the new one (before / after). Optional.
struct BeforePicker: View {
    let store: GameStore
    @Binding var selection: UUID?

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("前の写真とくらべる（なくてもOK）")
                .font(GameFont.caption(11))
                .foregroundStyle(GameColor.inkSoft)
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(store.album.photoEntries) { entry in
                        let selected = selection == entry.id
                        Button {
                            selection = selected ? nil : entry.id
                        } label: {
                            VStack(spacing: 2) {
                                PhotoThumb(url: store.photoURL(for: entry), size: 52)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 12)
                                            .stroke(
                                                selected ? GameColor.leaf : GameColor.line,
                                                lineWidth: selected ? 3 : 1.5))
                                Text(entry.day.shortTitle).font(GameFont.caption(10)).foregroundStyle(GameColor.inkSoft)
                            }
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("\(entry.day.displayTitle)の写真")
                        .accessibilityAddTraits(selected ? .isSelected : [])
                        .accessibilityIdentifier("before-choice")
                    }
                }
            }
        }
    }
}

/// Two photos side by side: what it was like, and what it is like now.
struct BeforeAfterPair: View {
    let before: MemoryEntry
    let beforeURL: URL?
    let after: MemoryEntry
    let afterURL: URL?

    var body: some View {
        HStack(alignment: .top, spacing: 6) {
            side(String(localized: "まえ"), before, beforeURL)
            Image(systemName: "arrow.right")
                .font(.system(size: 14, weight: .heavy))
                .foregroundStyle(GameColor.leafDark)
                .padding(.top, 44)
            side(String(localized: "あと"), after, afterURL)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(before.day.displayTitle)と\(after.day.displayTitle)の写真をくらべる")
        .accessibilityIdentifier("before-after")
    }

    private func side(_ title: String, _ entry: MemoryEntry, _ url: URL?) -> some View {
        VStack(spacing: 3) {
            Text(title).font(GameFont.body(11, weight: .heavy)).foregroundStyle(GameColor.leafDark)
            PhotoThumb(url: url, size: 104)
            Text(entry.day.shortTitle).font(GameFont.caption(10)).foregroundStyle(GameColor.inkSoft)
        }
        .frame(maxWidth: .infinity)
    }
}

extension LocalDay {
    /// "1/15" style, in the reader's locale.
    var shortTitle: String {
        let calendar = Calendar(identifier: .gregorian)
        guard let date = calendar.date(from: DateComponents(year: year, month: month, day: day)) else {
            return description
        }
        return date.formatted(.dateTime.month(.defaultDigits).day())
    }
}
