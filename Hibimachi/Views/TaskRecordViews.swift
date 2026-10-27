import HibimachiCore
import SwiftUI

/// What was kept for a quest just finished through a session: photos, amount, note, the record bonus and the
/// coach's comment (which may arrive a moment later).
struct FinishedTaskCard: View {
    let store: GameStore
    let task: FinishedTask

    var body: some View {
        let entry = task.entryID.flatMap(store.album.entry)
        VStack(alignment: .leading, spacing: 8) {
            Label(task.questTitle, systemImage: "checkmark.seal.fill")
                .font(GameFont.body(15, weight: .heavy))
                .foregroundStyle(GameColor.leafDark)
            if let bonus = task.bonus {
                Text("記録ボーナス +\(bonus.xpDelta) XP　✨+\(bonus.sparkleDelta)")
                    .font(GameFont.body(13, weight: .heavy))
                    .foregroundStyle(GameColor.wood)
                    .accessibilityIdentifier("record-bonus")
            }
            if let entry { RecordSummary(store: store, entry: entry) }
            if let comment = entry?.coachComment ?? (entry == nil ? task.check.ruleText : nil) {
                Label(comment, systemImage: "bubble.left.fill")
                    .font(GameFont.body(13, weight: .medium))
                    .foregroundStyle(GameColor.ink)
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityIdentifier("coach-comment")
            }
        }
        .gameCard(highlighted: true)
        .accessibilityIdentifier("finished-task")
    }
}

/// Photos (before → after when both exist), amount and note of one record.
struct RecordSummary: View {
    let store: GameStore
    let entry: MemoryEntry

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            if let beforeID = entry.beforeEntryID, let before = store.album.entry(beforeID) {
                BeforeAfterPair(
                    before: before, beforeURL: store.photoURL(for: before), after: entry,
                    afterURL: store.photoURL(for: entry))
            } else if entry.photo != nil {
                PhotoThumb(url: store.photoURL(for: entry), size: 104)
            }
            HStack(spacing: 8) {
                if let amount = entry.amount {
                    Label(amount.text, systemImage: "number")
                        .font(GameFont.body(13, weight: .bold))
                        .foregroundStyle(GameColor.ink)
                }
                if let text = entry.text {
                    Text(text).font(GameFont.body(13, weight: .medium)).foregroundStyle(GameColor.ink)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
    }
}
