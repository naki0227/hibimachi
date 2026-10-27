import HibimachiCore
import SwiftUI

/// What a goal card can ask the store to do. Each returns whether it worked (refusals show in the panel).
struct GoalActions {
    let addQuest: (String, Int) -> Bool
    let editQuest: (UUID, String, Int) -> Bool
    let removeQuest: (UUID) -> Bool
    let rename: (String) -> Bool
    let rest: () -> Void
    /// A proposed breakdown (AI or template) and applying the accepted one (ADR-0016).
    let makePlan: @MainActor () async -> (draft: PlanDraft, byAI: Bool)
    let applyPlan: (PlanDraft) -> Bool
}

/// Goal card that opens to show its steps and quests: break it into steps, rename the goal, edit or retire a
/// quest, add the player's own, or rest the goal ("おやすみ").
struct GoalRow: View {
    let goal: Goal
    let quests: [QuestTemplate]
    var steps: [StepStatus] = []
    let actions: GoalActions
    @State private var expanded = false
    @State private var planning = false
    @State private var renaming = false
    @State private var newTitle = ""
    @State private var editingQuest: UUID?
    @State private var draft = ""
    @State private var minutes = 5

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Button {
                withAnimation(.easeOut(duration: 0.2)) { expanded.toggle() }
            } label: {
                HStack {
                    Label(goal.title, systemImage: goal.category.symbolName)
                        .font(GameFont.body(16, weight: .bold))
                        .foregroundStyle(GameColor.ink)
                    Spacer()
                    Image(systemName: "chevron.down")
                        .font(.system(size: 13, weight: .heavy))
                        .foregroundStyle(GameColor.inkSoft)
                        .rotationEffect(.degrees(expanded ? 180 : 0))
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityValue(expanded ? String(localized: "ひらいています") : String(localized: "とじています"))
            .accessibilityIdentifier("goal-row")
            StepSummary(statuses: steps)
            if expanded { details }
        }
        .gameCard()
    }

    @ViewBuilder
    private var details: some View {
        if renaming {
            GameTextField(placeholder: "目標の名前", text: $newTitle)
                .accessibilityIdentifier("rename-goal-field")
            HStack(spacing: 8) {
                Button("やめる") { renaming = false }.buttonStyle(.game(.secondary, compact: true))
                Button("保存") { if actions.rename(newTitle) { renaming = false } }
                    .buttonStyle(.game(.primary, compact: true))
                    .accessibilityIdentifier("rename-goal-save")
            }
        }
        if planning {
            PlanEditor(goal: goal, makeDraft: actions.makePlan, apply: actions.applyPlan) { planning = false }
        } else {
            if !steps.isEmpty { StepList(statuses: steps, quests: quests) }
            Button {
                planning = true
            } label: {
                Label(
                    steps.isEmpty ? LocalizedStringKey("ステップに分ける") : LocalizedStringKey("ステップを作り直す"),
                    systemImage: "list.number")
            }
            .buttonStyle(.game(.secondary, compact: true))
            .accessibilityIdentifier("plan-goal")
        }
        if !steps.isEmpty {
            Text("いつものクエスト").font(GameFont.caption()).foregroundStyle(GameColor.inkSoft)
        }
        ForEach(quests.filter { $0.stepID == nil }) { quest in
            if editingQuest == quest.id {
                QuestEditor(quest: quest, actions: actions) { editingQuest = nil }
            } else {
                HStack {
                    Text("・\(quest.title)（\(quest.minutes)分）")
                        .font(GameFont.body(14, weight: .medium))
                        .foregroundStyle(GameColor.inkSoft)
                    Spacer(minLength: 4)
                    Button {
                        editingQuest = quest.id
                    } label: {
                        Image(systemName: "pencil").font(.system(size: 13, weight: .bold))
                    }
                    .buttonStyle(.game(.secondary, compact: true))
                    .accessibilityLabel("\(quest.title)を編集")
                    .accessibilityIdentifier("edit-quest")
                }
            }
        }
        GameTextField(placeholder: "自分のクエストを追加", text: $draft)
        HStack(spacing: 8) {
            MinutesStepper(minutes: $minutes)
            Spacer()
            Button("追加") { if actions.addQuest(draft, minutes) { draft = "" } }
                .buttonStyle(.game(.primary, compact: true))
                .disabled(draft.trimmingCharacters(in: .whitespaces).isEmpty)
        }
        HStack(spacing: 8) {
            if !renaming {
                Button("名前を変える") {
                    newTitle = goal.title
                    renaming = true
                }
                .buttonStyle(.game(.secondary, compact: true))
                .accessibilityIdentifier("rename-goal")
            }
            Button("この目標をおやすみする", action: actions.rest)
                .buttonStyle(.game(.secondary, compact: true))
        }
    }
}

/// Inline editor for one quest: wording, length, or "もう出さない" (retire).
private struct QuestEditor: View {
    let quest: QuestTemplate
    let actions: GoalActions
    let done: () -> Void
    @State private var title: String
    @State private var minutes: Int

    init(quest: QuestTemplate, actions: GoalActions, done: @escaping () -> Void) {
        self.quest = quest
        self.actions = actions
        self.done = done
        _title = State(initialValue: quest.title)
        _minutes = State(initialValue: quest.minutes)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            GameTextField(placeholder: "クエストの名前", text: $title)
                .accessibilityIdentifier("edit-quest-title")
            MinutesStepper(minutes: $minutes)
            HStack(spacing: 8) {
                Button("もう出さない") { if actions.removeQuest(quest.id) { done() } }
                    .buttonStyle(.game(.danger, compact: true))
                    .accessibilityIdentifier("remove-quest")
                Spacer()
                Button("やめる", action: done).buttonStyle(.game(.secondary, compact: true))
                Button("保存") { if actions.editQuest(quest.id, title, minutes) { done() } }
                    .buttonStyle(.game(.primary, compact: true))
                    .accessibilityIdentifier("save-quest")
            }
        }
        .padding(10)
        .background(GameColor.cream, in: RoundedRectangle(cornerRadius: 14))
    }
}

/// "− 5分 ＋" in 5-minute steps within the allowed range (1...60).
struct MinutesStepper: View {
    @Binding var minutes: Int

    var body: some View {
        HStack(spacing: 8) {
            Button {
                minutes = max(QuestTemplate.minutesRange.lowerBound, minutes - 5)
            } label: {
                Image(systemName: "minus")
            }
            .buttonStyle(.game(.secondary, compact: true))
            .accessibilityLabel("時間を減らす")
            Text("\(minutes)分").font(GameFont.body(15, weight: .bold)).monospacedDigit().frame(minWidth: 44)
            Button {
                minutes = min(QuestTemplate.minutesRange.upperBound, minutes + 5)
            } label: {
                Image(systemName: "plus")
            }
            .buttonStyle(.game(.secondary, compact: true))
            .accessibilityLabel("時間を増やす")
        }
    }
}
