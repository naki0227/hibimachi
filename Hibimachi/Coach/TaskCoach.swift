import Foundation
import HibimachiCore

/// The comment shown after finishing a quest through a session (ADR-0015). On-device AI when available and
/// allowed, otherwise the rule-based line. The reward never depends on it.
@MainActor
enum TaskCoach {
    static func comment(for task: FinishedTask, in store: GameStore, aiAllowed: Bool) async -> String {
        let fallback = task.check.ruleText
        guard aiAllowed, AppleIntelligenceCoach.isAvailable else { return fallback }
        let entry = task.entryID.flatMap(store.album.entry)
        let photoURL = entry.flatMap(store.photoURL(for:))
        // Classifying a photo is CPU work; keep it off the main actor.
        let labels = await Task.detached { photoURL.map(PhotoLabels.labels(at:)) ?? [] }.value
        let english = Bundle.main.preferredLocalizations.first == "en"
        let prompt = prompt(for: task, labels: labels)
        guard let reply = await AppleIntelligenceCoach.comment(prompt: prompt, english: english) else {
            return fallback
        }
        let cleaned = reply.replacingOccurrences(of: "\n", with: " ").trimmingCharacters(in: .whitespacesAndNewlines)
        return cleaned.isEmpty ? fallback : cleaned
    }

    /// Only what the player recorded goes in; labels are Vision's guesses about the photo.
    static func prompt(for task: FinishedTask, labels: [String]) -> String {
        var lines = ["task: \(task.questTitle)"]
        if let amount = task.check.amount { lines.append("amount: \(amount.value) \(amount.unit.rawValue)") }
        if let note = task.check.note { lines.append("note: \(note)") }
        if task.check.hasBeforePhoto && task.check.hasAfterPhoto { lines.append("before and after photos") }
        if !labels.isEmpty { lines.append("in the photo: \(labels.joined(separator: ", "))") }
        return lines.joined(separator: "\n")
    }
}

extension RecordCheck {
    /// What the coach says without AI.
    var ruleText: String {
        switch CoachLine.line(for: self) {
        case .tidied: String(localized: "すっきりしたね。島のみんなも気持ちよさそう。")
        case .made: String(localized: "いいものができたね。残せてよかった。")
        case .did(let amount): String(localized: "\(amount.text)、おつかれさま！")
        case .rested: String(localized: "ゆっくりできたなら、それがいちばん。")
        case .recorded: String(localized: "記録できたね。あとで見返すのが楽しみ。")
        case .finished: String(localized: "おつかれさま。島でひと休みしよう。")
        }
    }
}
