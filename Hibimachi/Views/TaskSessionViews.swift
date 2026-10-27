import HibimachiCore
import SwiftUI

/// The quest in progress (ADR-0015): what fits as a record for it, its photos so far, and finishing it.
struct SessionCard: View {
    let store: GameStore
    let session: TaskSession
    let finished: (FinishedTask) -> Void
    @State private var finishing = false

    var body: some View {
        let quest = store.quest(session.questID)
        let style = quest.map(store.recordStyle(of:)) ?? .result
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Label("いまやっていること", systemImage: "figure.walk.motion")
                    .font(GameFont.body(12, weight: .heavy))
                    .foregroundStyle(GameColor.leafDark)
                Spacer()
                ElapsedTime(since: session.startedAt)
            }
            Text(quest?.title ?? "").font(GameFont.body(17, weight: .heavy)).foregroundStyle(GameColor.ink)
            if finishing {
                FinishForm(store: store, quest: quest, style: style, back: { finishing = false }, finished: finished)
            } else {
                start(style)
            }
        }
        .gameCard(highlighted: true)
        // A container, so the buttons inside keep their own identifiers.
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("session-card")
    }

    @ViewBuilder
    private func start(_ style: RecordStyle) -> some View {
        Text(style.startHint).font(GameFont.caption()).foregroundStyle(GameColor.inkSoft)
            .fixedSize(horizontal: false, vertical: true)
        HStack(spacing: 8) {
            ForEach(session.photos, id: \.id) { photo in PhotoThumb(url: store.photoURL(for: photo), size: 44) }
            switch style {
            case .beforeAfter:
                PhotoCaptureButton(
                    title: session.beforePhoto == nil ? String(localized: "まえを撮る") : String(localized: "撮りなおす"),
                    identifier: "session-before"
                ) { store.attachSessionPhoto($0, to: .before) }
            case .amount:
                PhotoCaptureButton(title: String(localized: "途中を撮る"), identifier: "session-during") {
                    store.attachSessionPhoto($0, to: .during)
                }
            case .result, .feeling:
                EmptyView()
            }
        }
        HStack(spacing: 8) {
            Button("やめる") { store.cancelTask() }
                .buttonStyle(.game(.secondary, compact: true))
                .accessibilityIdentifier("session-cancel")
            Button {
                finishing = true
            } label: {
                Label("おわった", systemImage: "flag.checkered").frame(maxWidth: .infinity)
            }
            .buttonStyle(.game(.primary, compact: true))
            .accessibilityIdentifier("session-finish")
        }
    }
}

/// "おわった": the record that fits the quest (after photo, amount or a word), all optional.
private struct FinishForm: View {
    let store: GameStore
    let quest: QuestTemplate?
    let style: RecordStyle
    let back: () -> Void
    let finished: (FinishedTask) -> Void
    @State private var afterJPEG: Data?
    @State private var note = ""
    @State private var amount: Int?
    @State private var unit: AmountUnit = .minutes

    private var check: RecordCheck {
        RecordCheck(
            style: style, hasBeforePhoto: store.activeSession?.beforePhoto != nil, hasAfterPhoto: afterJPEG != nil,
            amount: amount.flatMap { TaskAmount(value: $0, unit: unit) }, note: note)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            switch style {
            case .beforeAfter, .result:
                HStack(spacing: 8) {
                    if let afterJPEG, let image = UIImage(data: afterJPEG) {
                        Image(uiImage: image).resizable().scaledToFill().frame(width: 44, height: 44)
                            .clipShape(RoundedRectangle(cornerRadius: 10))
                    }
                    PhotoCaptureButton(
                        title: style == .beforeAfter ? String(localized: "あとを撮る") : String(localized: "できたものを撮る"),
                        identifier: "finish-photo"
                    ) { afterJPEG = $0 }
                }
            case .amount:
                AmountInput(value: $amount, unit: $unit)
            case .feeling:
                EmptyView()
            }
            GameTextField(placeholder: style.notePlaceholder, text: $note, lines: 1...3)
                .accessibilityIdentifier("finish-note")
            Label(
                check.isComplete
                    ? String(localized: "記録がそろいました（✨+\(RewardRule.recordBonusSparkles)）") : style.completeHint,
                systemImage: check.isComplete ? "checkmark.seal.fill" : "seal"
            )
            .font(GameFont.caption())
            .foregroundStyle(check.isComplete ? GameColor.leafDark : GameColor.inkSoft)
            .fixedSize(horizontal: false, vertical: true)
            .accessibilityIdentifier("record-check")
            if let error = store.lastAlbumError {
                Text(error.message).font(GameFont.body(12)).foregroundStyle(GameColor.berryDark)
            }
            HStack(spacing: 8) {
                Button("もどる", action: back).buttonStyle(.game(.secondary, compact: true))
                Button {
                    let value = amount.flatMap { TaskAmount(value: $0, unit: unit) }
                    if let result = store.finishTask(afterJPEG: afterJPEG, amount: value, note: note) {
                        finished(result)
                    }
                } label: {
                    Text("やった！").frame(maxWidth: .infinity)
                }
                .buttonStyle(.game(.primary, compact: true))
                .accessibilityIdentifier("session-done")
            }
        }
        .onAppear {
            if let quest { unit = style.defaultUnit(forQuestTitled: quest.title) }
        }
    }
}

/// "どれくらいやった？": empty until the player sets it, so finishing without counting adds no amount.
private struct AmountInput: View {
    @Binding var value: Int?
    @Binding var unit: AmountUnit

    private var step: Int { unit == .minutes || unit == .times ? 5 : 1 }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("どれくらいやった？").font(GameFont.caption()).foregroundStyle(GameColor.inkSoft)
            HStack(spacing: 8) {
                Button {
                    value = max(TaskAmount.valueRange.lowerBound, (value ?? step) - step)
                } label: {
                    Image(systemName: "minus")
                }
                .buttonStyle(.game(.secondary, compact: true))
                .accessibilityLabel("減らす")
                Text(value.map { "\($0)" } ?? "—")
                    .font(GameFont.body(18, weight: .heavy)).monospacedDigit().frame(minWidth: 48)
                    .accessibilityIdentifier("amount-value")
                Button {
                    value = min(TaskAmount.valueRange.upperBound, (value ?? 0) + step)
                } label: {
                    Image(systemName: "plus")
                }
                .buttonStyle(.game(.secondary, compact: true))
                .accessibilityLabel("増やす")
                .accessibilityIdentifier("amount-plus")
            }
            Picker("単位", selection: $unit) {
                ForEach(AmountUnit.allCases, id: \.self) { unit in Text(unit.title).tag(unit) }
            }
            .pickerStyle(.segmented)
        }
    }
}

/// "12:34" since the session started, updated every second.
private struct ElapsedTime: View {
    let since: Date

    var body: some View {
        TimelineView(.periodic(from: .now, by: 1)) { context in
            let seconds = max(0, Int(context.date.timeIntervalSince(since)))
            Text(String(format: "%d:%02d", seconds / 60, seconds % 60))
                .font(GameFont.body(13, weight: .heavy)).monospacedDigit()
                .foregroundStyle(GameColor.inkSoft)
        }
    }
}
