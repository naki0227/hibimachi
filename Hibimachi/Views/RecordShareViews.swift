import HibimachiCore
import SwiftUI
import UIKit

/// What to put in a shared record. Chosen each time; photos start off (PRIVACY-AI: shared cards leave
/// photos out unless the player adds them).
struct ShareChoices: Hashable {
    var photos = false
    var words = true
    var comment = true
}

/// A picture of a record or of a day, built only from what the player chose to include.
struct RecordShareCard: View {
    let heading: String
    let subheading: String
    let photos: [UIImage]
    let lines: [String]
    let comment: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(subheading).font(GameFont.body(13, weight: .bold)).foregroundStyle(GameColor.inkSoft)
            Text(heading).font(GameFont.title(22)).foregroundStyle(GameColor.ink)
            if !photos.isEmpty {
                HStack(spacing: 8) {
                    ForEach(Array(photos.prefix(4).enumerated()), id: \.offset) { _, photo in
                        Image(uiImage: photo).resizable().scaledToFill()
                            .frame(maxWidth: .infinity).frame(height: photos.count == 1 ? 260 : 140)
                            .clipShape(RoundedRectangle(cornerRadius: 14))
                    }
                }
            }
            ForEach(Array(lines.enumerated()), id: \.offset) { _, line in
                Label(line, systemImage: "leaf.fill")
                    .font(GameFont.body(15, weight: .bold))
                    .foregroundStyle(GameColor.ink)
            }
            if let comment {
                Label(comment, systemImage: "bubble.left.fill")
                    .font(GameFont.body(14, weight: .medium))
                    .foregroundStyle(GameColor.leafDark)
            }
            HStack {
                Spacer()
                Text("ひびまち").font(GameFont.body(13, weight: .heavy)).foregroundStyle(GameColor.inkSoft)
            }
        }
        .padding(24)
        .frame(width: 360)
        .background(GameColor.paper)
        .environment(\.colorScheme, .light)
    }

    @MainActor
    func render() -> UIImage? {
        let renderer = ImageRenderer(content: self)
        renderer.scale = 3
        return renderer.uiImage
    }
}

/// Choices, a preview and the system share sheet. `makeCard` builds the card for the current choices.
struct ShareComposer: View {
    var hasPhotos = true
    var hasComment = true
    let makeCard: @MainActor (ShareChoices) -> RecordShareCard
    @State private var choices = ShareChoices()
    @State private var picture: UIImage?

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            VStack(spacing: 0) {
                if hasPhotos { choice(LocalizedStringKey("写真を入れる"), $choices.photos, "share-photos") }
                choice(LocalizedStringKey("量やひとことを入れる"), $choices.words, "share-words")
                if hasComment { choice(LocalizedStringKey("AIのひとことを入れる"), $choices.comment, "share-comment") }
            }
            if let picture {
                Image(uiImage: picture).resizable().scaledToFit()
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    .overlay(RoundedRectangle(cornerRadius: 12).stroke(GameColor.line, lineWidth: 1.5))
                    .accessibilityLabel("シェアする画像")
                ShareLink(
                    item: Image(uiImage: picture), preview: SharePreview(Text("ひびまち"), image: Image(uiImage: picture))
                ) {
                    Label("シェアする", systemImage: "square.and.arrow.up").frame(maxWidth: .infinity)
                }
                .buttonStyle(.game(.primary, compact: true))
                .accessibilityIdentifier("share-record-link")
            }
        }
        .task(id: choices) { picture = makeCard(choices).render() }
    }

    private func choice(_ title: LocalizedStringKey, _ value: Binding<Bool>, _ id: String) -> some View {
        Toggle(isOn: value) {
            Text(title).font(GameFont.body(13, weight: .bold)).foregroundStyle(GameColor.ink)
        }
        .toggleStyle(GameToggleStyle())
        .accessibilityIdentifier(id)
    }
}

/// Builds share cards from the album, so the composer only ever sees what the player recorded.
@MainActor
enum RecordShare {
    static func card(for task: FinishedTask, entry: MemoryEntry?, store: GameStore, choices: ShareChoices)
        -> RecordShareCard
    {
        var photos: [UIImage] = []
        if choices.photos, let entry {
            let before = entry.beforeEntryID.flatMap(store.album.entry)
            photos = [before, entry].compactMap { $0 }.compactMap { image(of: $0, store: store) }
        }
        var lines: [String] = []
        if choices.words, let entry {
            if let amount = entry.amount { lines.append(amount.text) }
            if let text = entry.text { lines.append(text) }
        }
        return RecordShareCard(
            heading: task.questTitle, subheading: String(localized: "やったこと"), photos: photos, lines: lines,
            comment: choices.comment ? entry?.coachComment : nil)
    }

    static func card(for day: AlbumDay, store: GameStore, choices: ShareChoices) -> RecordShareCard {
        var lines = day.quests.map(\.title)
        if choices.words {
            for memory in day.memories {
                if let amount = memory.amount { lines.append(amount.text) }
                if let text = memory.text { lines.append(text) }
            }
        }
        if day.sparklesEarned > 0 { lines.append(String(localized: "きらめき +\(day.sparklesEarned)")) }
        let photos = choices.photos ? day.memories.compactMap { image(of: $0, store: store) } : []
        let comment = choices.comment ? day.memories.compactMap(\.coachComment).last : nil
        return RecordShareCard(
            heading: day.day.displayTitle, subheading: String(localized: "きょうの日記"), photos: photos,
            lines: lines, comment: comment)
    }

    private static func image(of entry: MemoryEntry, store: GameStore) -> UIImage? {
        store.photoURL(for: entry).flatMap { UIImage(contentsOfFile: $0.path) }
    }
}
