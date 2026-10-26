import HibimachiCore
import SwiftUI

/// "きょうのこと": today's small quests, rewards and goals. Everything is optional and never punishes.
struct QuestPanel: View {
    let store: GameStore
    let close: () -> Void
    @State private var newGoalCategory: GoalCategory?
    @State private var newGoalTitle = ""
    @State private var pickingCategory = false

    var body: some View {
        GamePanel(title: "きょうのこと", symbol: "checklist", identifier: "quest-panel", close: close) {
            VStack(spacing: 14) {
                ProgressSummary(progress: store.progress)
                if let last = store.lastCompletion {
                    RewardBanner(reward: last.reward, undo: { store.undoLastCompletion() })
                    if let step = store.nextStep {
                        Label(step.message, systemImage: step.symbolName)
                            .font(GameFont.body(13, weight: .bold))
                            .foregroundStyle(GameColor.wood)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .fixedSize(horizontal: false, vertical: true)
                            .accessibilityIdentifier("next-step")
                    }
                }
                if let error = store.lastProgressError {
                    Label(error.message, systemImage: "exclamationmark.bubble.fill")
                        .font(GameFont.body(13))
                        .foregroundStyle(GameColor.berryDark)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                if let category = newGoalCategory {
                    NewGoalForm(category: category, title: $newGoalTitle) {
                        if store.addGoal(title: newGoalTitle, category: category) {
                            newGoalCategory = nil
                            pickingCategory = false
                        }
                    } cancel: {
                        newGoalCategory = nil
                    }
                } else if store.progress.activeGoals.isEmpty || pickingCategory {
                    Text("どんなことを育てたい？").gameSectionTitle()
                    categoryPicker
                } else {
                    todaySection
                    goalsSection
                }
            }
            .animation(.easeOut(duration: 0.2), value: newGoalCategory)
            .animation(.easeOut(duration: 0.2), value: pickingCategory)
        }
    }

    private var categoryPicker: some View {
        LazyVGrid(columns: [GridItem(.adaptive(minimum: 96), spacing: 10)], spacing: 10) {
            ForEach(GoalCategory.allCases, id: \.self) { category in
                Button {
                    newGoalTitle = category.defaultGoalTitle
                    newGoalCategory = category
                } label: {
                    VStack(spacing: 6) {
                        Image(systemName: category.symbolName).font(.system(size: 24, weight: .bold))
                            .foregroundStyle(GameColor.leafDark)
                        Text(category.title).font(GameFont.body(14, weight: .bold)).foregroundStyle(GameColor.ink)
                    }
                    .frame(maxWidth: .infinity, minHeight: 76)
                    .background(.white, in: RoundedRectangle(cornerRadius: 18))
                    .overlay(RoundedRectangle(cornerRadius: 18).stroke(GameColor.line, lineWidth: 2))
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier("goal-category-\(category.rawValue)")
            }
        }
    }

    @ViewBuilder
    private var todaySection: some View {
        let quests = store.todaysQuests
        Text("きょうのクエスト").gameSectionTitle()
        VStack(spacing: 8) {
            if quests.isEmpty {
                Label("今日の分はおしまい。島でゆっくりしましょう", systemImage: "moon.stars.fill")
                    .font(GameFont.body(14))
                    .foregroundStyle(GameColor.inkSoft)
                    .gameCard()
            }
            ForEach(Array(quests.enumerated()), id: \.element.id) { index, quest in
                QuestRow(
                    quest: quest,
                    goalTitle: store.progress.goals.first { $0.id == quest.goalID }?.title ?? "",
                    index: index,
                    complete: { store.completeQuest(quest.id) },
                    skip: { store.skipQuest(quest.id) })
            }
            ForEach(store.completedToday) { completion in
                let title = store.progress.quests.first { $0.id == completion.questID }?.title ?? ""
                Label(title, systemImage: "checkmark.circle.fill")
                    .font(GameFont.body(14))
                    .strikethrough(color: GameColor.leafDark.opacity(0.5))
                    .foregroundStyle(GameColor.leafDark)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 12)
            }
            Text("できたらタップ。できなかった日も、島は何も失いません。")
                .font(GameFont.caption())
                .foregroundStyle(GameColor.inkSoft)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    @ViewBuilder
    private var goalsSection: some View {
        Text("目標").gameSectionTitle()
        VStack(spacing: 8) {
            ForEach(store.progress.activeGoals) { goal in
                GoalRow(
                    goal: goal, quests: store.progress.quests(of: goal.id),
                    addQuest: { title, minutes in store.addQuest(to: goal.id, title: title, minutes: minutes) },
                    rest: { store.archiveGoal(goal.id) })
            }
            if store.progress.activeGoals.count < PlayerProgress.activeGoalLimit {
                Button {
                    pickingCategory = true
                } label: {
                    Label("目標を追加", systemImage: "plus").frame(maxWidth: .infinity)
                }
                .buttonStyle(.game(.secondary))
                .accessibilityIdentifier("add-goal")
            }
        }
    }
}

extension GoalCategory: @retroactive Identifiable {
    public var id: String { rawValue }
}

/// Inline "new goal" card (was a nested system sheet).
struct NewGoalForm: View {
    let category: GoalCategory
    @Binding var title: String
    let save: () -> Void
    let cancel: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label(category.title, systemImage: category.symbolName)
                .font(GameFont.body(18, weight: .heavy))
                .foregroundStyle(GameColor.leafDark)
            GameTextField(placeholder: "目標の名前", text: $title)
                .accessibilityIdentifier("goal-title")
            Text("「\(category.title)」の小さなクエストが3つ用意されます。あとで自分のクエストも足せます。")
                .font(GameFont.caption())
                .foregroundStyle(GameColor.inkSoft)
                .fixedSize(horizontal: false, vertical: true)
            HStack(spacing: 10) {
                Button("やめる", action: cancel).buttonStyle(.game(.secondary))
                Button(action: save) {
                    Text("はじめる").frame(maxWidth: .infinity)
                }
                .buttonStyle(.game)
                .disabled(title.trimmingCharacters(in: .whitespaces).isEmpty)
                .accessibilityIdentifier("create-goal")
            }
        }
        .gameCard(highlighted: true)
    }
}
