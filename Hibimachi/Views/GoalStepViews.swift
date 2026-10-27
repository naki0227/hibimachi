import HibimachiCore
import SwiftUI

/// The bar used for step progress (same look as the level bar).
struct StepBar: View {
    let fraction: Double

    var body: some View {
        Capsule()
            .fill(GameColor.cream)
            .overlay(alignment: .leading) {
                GeometryReader { proxy in
                    Capsule().fill(GameColor.leaf).frame(width: max(8, proxy.size.width * fraction))
                }
            }
            .overlay(Capsule().stroke(GameColor.line, lineWidth: 1.5))
            .frame(height: 10)
    }
}

/// One line under a closed goal card: which step it is on and how far (ADR-0016).
struct StepSummary: View {
    let statuses: [StepStatus]

    var body: some View {
        if let index = statuses.firstIndex(where: \.isCurrent) {
            let current = statuses[index]
            VStack(alignment: .leading, spacing: 4) {
                Text("ステップ \(index + 1)/\(statuses.count)：\(current.step.title)")
                    .font(GameFont.body(13, weight: .bold))
                    .foregroundStyle(GameColor.ink)
                HStack(spacing: 8) {
                    StepBar(fraction: current.fraction)
                    Text("\(current.done)/\(current.step.target)回")
                        .font(GameFont.caption(12)).monospacedDigit().foregroundStyle(GameColor.inkSoft)
                }
            }
            .accessibilityElement(children: .combine)
            .accessibilityIdentifier("step-summary")
        } else if !statuses.isEmpty {
            Label("すべてのステップを終えました！", systemImage: "flag.checkered")
                .font(GameFont.body(13, weight: .heavy))
                .foregroundStyle(GameColor.leafDark)
                .accessibilityIdentifier("step-summary")
        }
    }
}

/// All steps of an open goal card: finished ones checked, the current one with its quests, later ones waiting.
struct StepList: View {
    let statuses: [StepStatus]
    let quests: [QuestTemplate]

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            ForEach(Array(statuses.enumerated()), id: \.element.step.id) { index, status in
                VStack(alignment: .leading, spacing: 4) {
                    let count = min(status.done, status.step.target)
                    Label {
                        Text("\(index + 1). \(status.step.title)（\(count)/\(status.step.target)回）")
                    } icon: {
                        Image(systemName: icon(for: status))
                    }
                    .font(GameFont.body(14, weight: status.isCurrent ? .heavy : .medium))
                    .foregroundStyle(status.isFinished || status.isCurrent ? GameColor.leafDark : GameColor.inkSoft)
                    if status.isCurrent {
                        StepBar(fraction: status.fraction)
                        ForEach(quests.filter { $0.stepID == status.step.id && !$0.isRetired }) { quest in
                            Text("・\(quest.title)（\(quest.minutes)分）")
                                .font(GameFont.body(13, weight: .medium))
                                .foregroundStyle(GameColor.inkSoft)
                        }
                    }
                }
            }
        }
        .padding(10)
        .background(GameColor.cream, in: RoundedRectangle(cornerRadius: 14))
        .accessibilityIdentifier("step-list")
    }

    private func icon(for status: StepStatus) -> String {
        if status.isFinished { return "checkmark.circle.fill" }
        return status.isCurrent ? "figure.walk" : "circle.dotted"
    }
}

/// Edits a proposed breakdown before it is applied: rename or remove steps, change counts and quest names,
/// ask again, or accept. The draft comes from on-device AI or the category template (`PlanCoach`).
struct PlanEditor: View {
    let goal: Goal
    let makeDraft: @MainActor () async -> (draft: PlanDraft, byAI: Bool)
    let apply: (PlanDraft) -> Bool
    let close: () -> Void
    @State private var draft: PlanDraft?
    @State private var byAI = false
    @State private var attempt = 0

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("「\(goal.title)」をステップに分ける").font(GameFont.body(15, weight: .heavy))
                .foregroundStyle(GameColor.ink)
            if let draft {
                Text(byAI ? LocalizedStringKey("AIの案です。自由に直してください。") : LocalizedStringKey("ひな形の案です。自由に直してください。"))
                    .font(GameFont.caption()).foregroundStyle(GameColor.inkSoft)
                    .accessibilityIdentifier("plan-source")
                ForEach(draft.steps.indices, id: \.self) { index in
                    stepEditor(index, canRemove: draft.steps.count > PlanDraft.stepCount.lowerBound)
                }
                HStack(spacing: 8) {
                    Button("やめる", action: close).buttonStyle(.game(.secondary, compact: true))
                    Button("ほかの案") {
                        self.draft = nil
                        attempt += 1
                    }
                    .buttonStyle(.game(.secondary, compact: true))
                    Button {
                        if apply(draft) { close() }
                    } label: {
                        Text("これで始める").frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.game(.primary, compact: true))
                    .accessibilityIdentifier("plan-apply")
                }
            } else {
                HStack(spacing: 8) {
                    ProgressView().tint(GameColor.leafDark)
                    Text("考えています…").font(GameFont.body(13)).foregroundStyle(GameColor.inkSoft)
                }
            }
        }
        .padding(10)
        .background(GameColor.cream, in: RoundedRectangle(cornerRadius: 14))
        .task(id: attempt) {
            let result = await makeDraft()
            draft = result.draft
            byAI = result.byAI
        }
    }

    @ViewBuilder
    private func stepEditor(_ index: Int, canRemove: Bool) -> some View {
        if let binding = stepBinding(index) {
            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 6) {
                    Text("\(index + 1).").font(GameFont.body(14, weight: .heavy)).foregroundStyle(GameColor.leafDark)
                    GameTextField(placeholder: "ステップの名前", text: binding.title)
                        .accessibilityIdentifier("plan-step-\(index)")
                    if canRemove {
                        Button {
                            draft?.steps.remove(at: index)
                        } label: {
                            Image(systemName: "trash")
                        }
                        .buttonStyle(.game(.secondary, compact: true))
                        .accessibilityLabel("このステップを消す")
                    }
                }
                CountStepper(count: binding.target)
                ForEach(binding.wrappedValue.quests.indices, id: \.self) { questIndex in
                    GameTextField(placeholder: "クエストの名前", text: binding.quests[questIndex].title)
                }
            }
            .padding(8)
            .background(GameColor.paper, in: RoundedRectangle(cornerRadius: 12))
        }
    }

    private func stepBinding(_ index: Int) -> Binding<PlanDraft.Step>? {
        guard let steps = draft?.steps, steps.indices.contains(index) else { return nil }
        return Binding(
            get: { draft?.steps[safe: index] ?? steps[index] },
            set: { value in if draft?.steps.indices.contains(index) == true { draft?.steps[index] = value } })
    }
}

/// "− 7回 ＋" for a step's rough count.
private struct CountStepper: View {
    @Binding var count: Int

    var body: some View {
        HStack(spacing: 8) {
            Text("目安").font(GameFont.caption()).foregroundStyle(GameColor.inkSoft)
            Button {
                count = max(GoalStep.targetRange.lowerBound, count - 1)
            } label: {
                Image(systemName: "minus")
            }
            .buttonStyle(.game(.secondary, compact: true))
            .accessibilityLabel("回数を減らす")
            Text("\(count)回").font(GameFont.body(14, weight: .bold)).monospacedDigit().frame(minWidth: 40)
            Button {
                count = min(GoalStep.targetRange.upperBound, count + 1)
            } label: {
                Image(systemName: "plus")
            }
            .buttonStyle(.game(.secondary, compact: true))
            .accessibilityLabel("回数を増やす")
        }
    }
}

extension Array {
    fileprivate subscript(safe index: Int) -> Element? { indices.contains(index) ? self[index] : nil }
}

/// "削除" that asks once before deleting a goal. What was already done (XP, album, past days) stays.
struct DeleteGoalButton: View {
    let title: String
    let delete: () -> Void
    @State private var confirming = false

    var body: some View {
        if confirming {
            VStack(alignment: .leading, spacing: 6) {
                Text("「\(title)」を削除しますか？これまでの記録とXPは残ります。")
                    .font(GameFont.caption())
                    .foregroundStyle(GameColor.berryDark)
                    .fixedSize(horizontal: false, vertical: true)
                HStack(spacing: 8) {
                    Button("やめる") { confirming = false }.buttonStyle(.game(.secondary, compact: true))
                    Button("削除する", action: delete)
                        .buttonStyle(.game(.danger, compact: true))
                        .accessibilityIdentifier("delete-goal-confirm")
                }
            }
        } else {
            Button {
                confirming = true
            } label: {
                Label("削除", systemImage: "trash")
            }
            .buttonStyle(.game(.danger, compact: true))
            .accessibilityLabel("「\(title)」を削除")
            .accessibilityIdentifier("delete-goal")
        }
    }
}
