import HibimachiCore
import PhotosUI
import SwiftUI

/// "アルバム": optional memories and the island's history by day. Nothing here is required to play.
struct AlbumPanel: View {
    let store: GameStore
    let close: () -> Void

    var body: some View {
        GamePanel(title: "アルバム", symbol: "photo.on.rectangle.angled", identifier: "album-panel", close: close) {
            VStack(spacing: 14) {
                MemoryComposer(store: store)
                Label(storageText, systemImage: "lock.fill")
                    .font(GameFont.caption())
                    .foregroundStyle(GameColor.inkSoft)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .accessibilityIdentifier("album-storage")
                let days = store.albumDays
                if days.isEmpty {
                    Text("まだ記録はありません。クエストをやった日や、島に何かを迎えた日がここに並びます。")
                        .font(GameFont.body(14, weight: .medium))
                        .foregroundStyle(GameColor.inkSoft)
                        .gameCard()
                }
                ForEach(days) { day in
                    AlbumDayCard(day: day, store: store)
                }
            }
        }
    }

    private var storageText: String {
        let megabytes = Double(store.album.photoBytes) / 1_000_000
        let size = megabytes.formatted(.number.precision(.fractionLength(1)))
        return String(localized: "写真 \(store.album.photoCount)枚・\(size)MB（この端末の中だけに保存）")
    }
}

/// Today's entry: a short text, an optional photo (system picker, no library permission) and an optional
/// link to one of today's finished quests.
private struct MemoryComposer: View {
    let store: GameStore
    @State private var text = ""
    @State private var pickerItem: PhotosPickerItem?
    @State private var photoJPEG: Data?
    @State private var linkedCompletion: UUID?
    @State private var beforeID: UUID?
    @FocusState private var editing: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("きょうの記録").gameSectionTitle()
            GameTextField(placeholder: "ひとこと（なくてもOK）", text: $text, lines: 2...4)
                .focused($editing)
                .accessibilityIdentifier("memory-text")
            HStack(spacing: 8) {
                PhotosPicker(selection: $pickerItem, matching: .images) {
                    Label(
                        photoJPEG == nil ? String(localized: "写真をえらぶ") : String(localized: "写真をかえる"),
                        systemImage: "photo")
                }
                .buttonStyle(.game(.secondary, compact: true))
                if let photoJPEG, let image = UIImage(data: photoJPEG) {
                    Image(uiImage: image).resizable().scaledToFill()
                        .frame(width: 40, height: 40)
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                    Button {
                        self.photoJPEG = nil
                        pickerItem = nil
                        beforeID = nil
                    } label: {
                        Image(systemName: "xmark")
                    }
                    .buttonStyle(.game(.secondary, compact: true))
                    .accessibilityLabel("写真をはずす")
                }
                Spacer(minLength: 0)
                Text("\(text.count)/\(Album.textLimit)")
                    .font(GameFont.caption(11))
                    .foregroundStyle(text.count > Album.textLimit ? GameColor.berry : GameColor.inkSoft)
            }
            if photoJPEG != nil, !store.album.photoEntries.isEmpty {
                BeforePicker(store: store, selection: $beforeID)
            }
            if !store.completedToday.isEmpty { completionChips }
            if let error = store.lastAlbumError {
                Text(error.message).font(GameFont.body(12)).foregroundStyle(GameColor.berryDark)
            }
            Button(action: save) {
                Label("のこす", systemImage: "leaf.fill").frame(maxWidth: .infinity)
            }
            .buttonStyle(.game)
            .disabled(text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && photoJPEG == nil)
            .accessibilityIdentifier("save-memory")
        }
        .gameCard()
        .task(id: pickerItem) {
            guard let pickerItem, let data = try? await pickerItem.loadTransferable(type: Data.self) else { return }
            // Decoding and resizing a large photo is CPU work; keep it off the main actor.
            photoJPEG = await Task.detached { PhotoPrep.albumJPEG(from: data) }.value
        }
    }

    private var completionChips: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 6) {
                ForEach(store.completedToday) { completion in
                    let title = store.progress.quests.first { $0.id == completion.questID }?.title ?? ""
                    let selected = linkedCompletion == completion.id
                    Button {
                        linkedCompletion = selected ? nil : completion.id
                    } label: {
                        Label(title, systemImage: selected ? "checkmark.circle.fill" : "circle")
                            .font(GameFont.body(12, weight: .bold))
                            .padding(.horizontal, 10)
                            .frame(minHeight: 32)
                            .foregroundStyle(selected ? .white : GameColor.ink)
                            .background(selected ? GameColor.leaf : .white, in: Capsule())
                            .overlay(Capsule().stroke(GameColor.line, lineWidth: 2))
                    }
                    .buttonStyle(.plain)
                    .accessibilityAddTraits(selected ? .isSelected : [])
                }
            }
        }
    }

    private func save() {
        if store.addMemory(text: text, photoJPEG: photoJPEG, completionID: linkedCompletion, before: beforeID) {
            editing = false
            text = ""
            photoJPEG = nil
            pickerItem = nil
            linkedCompletion = nil
            beforeID = nil
        }
    }
}

struct AlbumDayCard: View {
    let day: AlbumDay
    let store: GameStore

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(day.day.displayTitle).font(GameFont.body(16, weight: .heavy)).foregroundStyle(GameColor.ink)
                Spacer()
                if day.sparklesEarned > 0 {
                    Label("+\(day.sparklesEarned)", systemImage: "sparkles")
                        .font(GameFont.body(12, weight: .heavy))
                        .foregroundStyle(GameColor.wood)
                }
            }
            ForEach(day.quests, id: \.completionID) { quest in
                Label(quest.title, systemImage: "checkmark.circle.fill")
                    .font(GameFont.body(13, weight: .semibold))
                    .foregroundStyle(GameColor.leafDark)
            }
            ForEach(Array(day.purchases.enumerated()), id: \.offset) { _, kind in
                Label("\(kind.displayName)を迎えた", systemImage: "house.fill")
                    .font(GameFont.body(13, weight: .semibold))
                    .foregroundStyle(GameColor.wood)
            }
            ForEach(day.memories) { entry in
                if let beforeID = entry.beforeEntryID, let before = store.album.entry(beforeID) {
                    BeforeAfterPair(
                        before: before, beforeURL: store.photoURL(for: before), after: entry,
                        afterURL: store.photoURL(for: entry))
                }
                MemoryRow(entry: entry, photoURL: store.photoURL(for: entry)) { store.deleteMemory(entry.id) }
            }
        }
        .gameCard()
    }
}

private struct MemoryRow: View {
    let entry: MemoryEntry
    let photoURL: URL?
    let delete: () -> Void
    @State private var confirming = false

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            if entry.photo != nil, entry.beforeEntryID == nil {
                PhotoThumb(url: photoURL).accessibilityLabel("記録の写真")
            }
            Text(entry.text ?? "")
                .font(GameFont.body(14, weight: .medium))
                .foregroundStyle(GameColor.ink)
                .frame(maxWidth: .infinity, alignment: .leading)
                .fixedSize(horizontal: false, vertical: true)
            Button(confirming ? String(localized: "けす？") : String(localized: "けす")) {
                if confirming { delete() } else { confirming = true }
            }
            .buttonStyle(.game(confirming ? .danger : .secondary, compact: true))
            .accessibilityLabel(confirming ? String(localized: "本当にこの記録をけす") : String(localized: "この記録をけす"))
        }
        .padding(8)
        .background(GameColor.cream.opacity(0.6), in: RoundedRectangle(cornerRadius: 14))
        .accessibilityIdentifier("memory-row")
    }
}

extension LocalDay {
    /// Month, day and weekday in the reader's language: "1月15日(金)" / "Fri, Jan 15".
    var displayTitle: String {
        let calendar = Calendar(identifier: .gregorian)
        guard let date = calendar.date(from: DateComponents(year: year, month: month, day: day)) else {
            return description
        }
        return date.formatted(.dateTime.month(.abbreviated).day().weekday(.abbreviated))
    }
}

extension AlbumError {
    var message: String {
        switch self {
        case .empty: String(localized: "ひとことか写真のどちらかを入れてください")
        case .textTooLong(let limit): String(localized: "ひとことは\(limit)文字までです")
        case .unknownCompletion: String(localized: "そのクエストの記録が見つかりませんでした")
        case .notFound: String(localized: "その記録はもうありません")
        case .photoUnavailable, .photoSaveFailed: String(localized: "写真を保存できませんでした。ことばだけなら残せます")
        case .comparisonNeedsPhotos: String(localized: "くらべるには、両方に写真が必要です")
        }
    }
}
