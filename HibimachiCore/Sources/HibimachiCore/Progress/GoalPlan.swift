import Foundation

/// A middle step of a goal (ADR-0016): "do these quests about `target` times, then move on".
/// Steps run in the order they are stored; progress is counted from completions, never stored.
public struct GoalStep: Identifiable, Equatable, Sendable {
    public static let targetRange = 1...99

    public let id: UUID
    public let goalID: UUID
    public var title: String
    public var target: Int

    public init(id: UUID, goalID: UUID, title: String, target: Int) {
        self.id = id
        self.goalID = goalID
        self.title = title
        self.target = target
    }
}

/// Where one step stands.
public struct StepStatus: Equatable, Sendable {
    public let step: GoalStep
    /// Completions of the step's quests (may exceed the target).
    public let done: Int
    public let isCurrent: Bool

    public var isFinished: Bool { done >= step.target }
    /// 0...1 for a progress bar.
    public var fraction: Double { min(Double(done) / Double(step.target), 1) }
}

/// A proposed breakdown of a goal into steps and quests, before the player accepts it. Comes from a category
/// template or from on-device AI text (`parse`); either way it is clamped to the same limits.
public struct PlanDraft: Equatable, Sendable {
    public static let stepCount = 2...5
    public static let questsPerStep = 1...3

    public struct Quest: Equatable, Sendable {
        public var title: String
        public var minutes: Int

        public init(title: String, minutes: Int) {
            self.title = title
            self.minutes = minutes
        }
    }

    public struct Step: Equatable, Sendable {
        public var title: String
        public var target: Int
        public var quests: [Quest]

        public init(title: String, target: Int, quests: [Quest]) {
            self.title = title
            self.target = target
            self.quests = quests
        }
    }

    public var steps: [Step]

    public init(steps: [Step]) { self.steps = steps }

    /// Reads the AI's answer: `STEP: title | count` lines, each followed by `- quest | minutes` lines.
    /// Anything else is ignored. `nil` when fewer than the minimum number of usable steps come out.
    public static func parse(_ text: String) -> PlanDraft? {
        var steps: [Step] = []
        for raw in text.split(whereSeparator: \.isNewline) {
            let line = raw.trimmingCharacters(in: .whitespaces)
            if let body = line.dropPrefix(caseInsensitive: "STEP:") {
                guard steps.count < stepCount.upperBound else { break }
                let (title, number) = split(body)
                guard let title else { continue }
                steps.append(Step(title: title, target: clamp(number ?? 7, to: GoalStep.targetRange), quests: []))
            } else if let body = line.dropPrefix(caseInsensitive: "-") ?? line.dropPrefix(caseInsensitive: "・"),
                !steps.isEmpty, steps[steps.count - 1].quests.count < questsPerStep.upperBound
            {
                let (title, number) = split(body)
                guard let title else { continue }
                let minutes = clamp(number ?? 5, to: QuestTemplate.minutesRange)
                steps[steps.count - 1].quests.append(Quest(title: title, minutes: minutes))
            }
        }
        let usable = steps.filter { !$0.quests.isEmpty }
        return usable.count >= stepCount.lowerBound ? PlanDraft(steps: usable) : nil
    }

    /// "title | 12" → ("title", 12). Titles are trimmed and cut to the goal title limit.
    private static func split(_ body: Substring) -> (String?, Int?) {
        let parts = body.split(separator: "|", maxSplits: 1)
        let title = parts.first.map { String($0).trimmingCharacters(in: .whitespaces) } ?? ""
        let digits = parts.count > 1 ? parts[1].filter(\.isNumber) : ""
        let number = Int(String(digits.prefix(3)))
        guard !title.isEmpty else { return (nil, number) }
        return (String(title.prefix(Goal.titleLimit)), number)
    }

    private static func clamp(_ value: Int, to range: ClosedRange<Int>) -> Int {
        min(max(value, range.lowerBound), range.upperBound)
    }
}

extension String {
    fileprivate func dropPrefix(caseInsensitive prefix: String) -> Substring? {
        guard lowercased().hasPrefix(prefix.lowercased()) else { return nil }
        return dropFirst(prefix.count)
    }
}
