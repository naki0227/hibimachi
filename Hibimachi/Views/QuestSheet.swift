import HibimachiCore
import SwiftUI

/// "きょうのこと": today's small quests, rewards and goals. Everything is optional and never punishes.
struct QuestSheet: View {
    let store: GameStore
    @Environment(\.dismiss) private var dismiss
    @State private var newGoalCategory: GoalCategory?
    @State private var newGoalTitle = ""

    var body: some View {
        NavigationStack {
            List {
                Section { ProgressSummary(progress: store.progress) }
                if let last = store.lastCompletion {
                    Section { RewardBanner(reward: last.reward, undo: { store.undoLastCompletion() }) }
                }
                if let error = store.lastProgressError {
                    Text(error.message).font(.footnote).foregroundStyle(.red)
                }
                if store.progress.activeGoals.isEmpty {
                    Section("どんなことを育てたい？") { categoryPicker }
                } else {
                    todaySection
                    goalsSection
                }
            }
            .navigationTitle("きょうのこと")
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("閉じる") { dismiss() }
                }
            }
            .sheet(item: $newGoalCategory) { category in
                NewGoalForm(category: category, title: $newGoalTitle) {
                    if store.addGoal(title: newGoalTitle, category: category) { newGoalCategory = nil }
                }
                .presentationDetents([.medium])
            }
        }
    }

    private var categoryPicker: some View {
        LazyVGrid(columns: [GridItem(.adaptive(minimum: 96))], spacing: 10) {
            ForEach(GoalCategory.allCases, id: \.self) { category in
                Button {
                    newGoalTitle = category.defaultGoalTitle
                    newGoalCategory = category
                } label: {
                    VStack(spacing: 6) {
                        Image(systemName: category.symbolName).font(.title2)
                        Text(category.title).font(.system(.subheadline, design: .rounded).weight(.semibold))
                    }
                    .frame(maxWidth: .infinity, minHeight: 72)
                    .background(Color.green.opacity(0.12), in: RoundedRectangle(cornerRadius: 14))
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier("goal-category-\(category.rawValue)")
            }
        }
        .padding(.vertical, 4)
    }

    private var todaySection: some View {
        Section {
            let quests = store.todaysQuests
            if quests.isEmpty {
                Text("今日の分はおしまい。島でゆっくりしましょう").foregroundStyle(.secondary)
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
                    .foregroundStyle(.green)
                    .font(.subheadline)
            }
        } header: {
            Text("きょうのクエスト")
        } footer: {
            Text("できたらタップ。できなかった日も、島は何も失いません。")
        }
    }

    private var goalsSection: some View {
        Section("目標") {
            ForEach(store.progress.activeGoals) { goal in
                GoalRow(goal: goal, quests: store.progress.quests(of: goal.id)) { title, minutes in
                    store.addQuest(to: goal.id, title: title, minutes: minutes)
                }
                .swipeActions {
                    Button("おやすみ") { store.archiveGoal(goal.id) }.tint(.orange)
                }
            }
            if store.progress.activeGoals.count < PlayerProgress.activeGoalLimit {
                Menu {
                    ForEach(GoalCategory.allCases, id: \.self) { category in
                        Button(category.title, systemImage: category.symbolName) {
                            newGoalTitle = category.defaultGoalTitle
                            newGoalCategory = category
                        }
                    }
                } label: {
                    Label("目標を追加", systemImage: "plus.circle")
                }
                .accessibilityIdentifier("add-goal")
            }
        }
    }
}

extension GoalCategory: @retroactive Identifiable {
    public var id: String { rawValue }
}

struct ProgressSummary: View {
    let progress: PlayerProgress

    var body: some View {
        let xpInLevel = progress.totalXP % RewardRule.xpPerLevel
        HStack(spacing: 16) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Lv \(progress.level)").font(.system(.title2, design: .rounded).weight(.heavy))
                ProgressView(value: Double(xpInLevel), total: Double(RewardRule.xpPerLevel))
                    .tint(.green)
                Text("次のレベルまで \(RewardRule.xpPerLevel - xpInLevel) XP").font(.caption).foregroundStyle(.secondary)
            }
            Spacer()
            VStack(spacing: 2) {
                Image(systemName: "sparkles").foregroundStyle(.orange)
                Text("\(progress.sparkles)").font(.system(.title3, design: .rounded).weight(.bold)).monospacedDigit()
                Text("きらめき").font(.caption2).foregroundStyle(.secondary)
            }
        }
        .accessibilityElement(children: .combine)
    }
}

struct RewardBanner: View {
    let reward: RewardTransaction
    let undo: () -> Void

    var body: some View {
        HStack {
            Label("+\(reward.xpDelta) XP　✨+\(reward.sparkleDelta)", systemImage: "leaf.fill")
                .font(.system(.headline, design: .rounded))
                .foregroundStyle(.green)
            Spacer()
            Button("取り消す", action: undo)
                .font(.footnote)
                .accessibilityIdentifier("undo-completion")
        }
        .accessibilityIdentifier("reward-banner")
    }
}

struct QuestRow: View {
    let quest: QuestTemplate
    let goalTitle: String
    let index: Int
    let complete: () -> Void
    let skip: () -> Void

    var body: some View {
        HStack(spacing: 10) {
            VStack(alignment: .leading, spacing: 2) {
                Text(quest.title).font(.system(.body, design: .rounded).weight(.semibold))
                Text("\(goalTitle)・約\(quest.minutes)分").font(.caption).foregroundStyle(.secondary)
            }
            Spacer(minLength: 4)
            Button("ほかの", action: skip)
                .font(.caption)
                .buttonStyle(.bordered)
                .accessibilityLabel("ほかのクエストにする")
            Button("やった！", action: complete)
                .buttonStyle(.borderedProminent)
                .tint(.green)
                .accessibilityIdentifier("quest-done-\(index)")
        }
        .padding(.vertical, 2)
    }
}

struct GoalRow: View {
    let goal: Goal
    let quests: [QuestTemplate]
    let addQuest: (String, Int) -> Bool
    @State private var draft = ""
    @State private var minutes = 5

    var body: some View {
        DisclosureGroup {
            ForEach(quests) { quest in
                Text("・\(quest.title)（\(quest.minutes)分）").font(.subheadline)
            }
            HStack {
                TextField("自分のクエストを追加", text: $draft)
                Stepper("\(minutes)分", value: $minutes, in: 1...60, step: 5).fixedSize()
                Button("追加") { if addQuest(draft, minutes) { draft = "" } }
                    .disabled(draft.trimmingCharacters(in: .whitespaces).isEmpty)
            }
            .font(.subheadline)
        } label: {
            Label(goal.title, systemImage: goal.category.symbolName)
        }
    }
}

struct NewGoalForm: View {
    let category: GoalCategory
    @Binding var title: String
    let save: () -> Void

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("目標の名前", text: $title)
                        .accessibilityIdentifier("goal-title")
                } footer: {
                    Text("「\(category.title)」の小さなクエストが3つ用意されます。あとで自分のクエストも足せます。")
                }
                Button("はじめる", action: save)
                    .frame(maxWidth: .infinity)
                    .accessibilityIdentifier("create-goal")
            }
            .navigationTitle(category.title)
        }
    }
}
