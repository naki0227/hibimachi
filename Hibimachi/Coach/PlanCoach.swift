import Foundation
import HibimachiCore

/// Proposes steps for a goal (ADR-0016): on-device AI when available and allowed, otherwise (or when its answer
/// cannot be read) the category template. The player edits and accepts the draft; nothing is applied here.
@MainActor
enum PlanCoach {
    /// Writing a whole plan takes longer than a one-line comment.
    static let timeout: Duration = .seconds(20)

    static func draft(for goal: Goal, aiAllowed: Bool) async -> (draft: PlanDraft, byAI: Bool) {
        let language = QuestPresets.Language.current
        let template = PlanDraft.template(for: goal.category, language: language)
        guard aiAllowed, AppleIntelligenceCoach.isAvailable else { return (template, false) }
        let instructions = language == .english ? englishInstructions : japaneseInstructions
        guard
            let reply = await AppleIntelligenceCoach.respond(
                to: prompt(for: goal), instructions: instructions, timeout: timeout),
            let parsed = PlanDraft.parse(reply)
        else { return (template, false) }
        return (parsed, true)
    }

    /// Only the goal's own words and its category go in.
    static func prompt(for goal: Goal) -> String {
        "goal: \(goal.title)\ncategory: \(goal.category.rawValue)"
    }

    static let japaneseInstructions = """
        あなたは習慣づくりを手伝う、やさしい相談相手です。
        プレイヤーの目標を、順番に進める3〜4個の「ステップ」に分けます。
        各ステップには、5〜15分でできる小さなクエストを2つ付けます。
        次の書式だけで答えてください。説明や前置きは書きません。
        STEP: ステップの名前 | 目安の回数
        - クエストの名前 | 分
        ・名前はどれも20文字以内。
        ・目安の回数は5〜30回。あとのステップほど少し多くする。
        ・最初のステップは、今日すぐできるくらい小さくする。
        ・無理な量や、健康・お金に関わる指示はしない。
        """

    static let englishInstructions = """
        You are a gentle helper for building habits.
        Break the player's goal into 3 or 4 ordered "steps".
        Give each step 2 small quests that take 5 to 15 minutes.
        Answer only in this format, with no explanation or preamble:
        STEP: step name | rough number of times
        - quest name | minutes
        - Every name is at most 28 characters.
        - The number of times is between 5 and 30, a little more for later steps.
        - Make the first step small enough to start today.
        - No demanding amounts, and no health or money advice.
        """
}
