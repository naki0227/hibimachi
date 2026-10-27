import Foundation

/// What fits as a record of a quest (ADR-0015). Decided by rules: words in the quest's title first, then the
/// goal's category. Every style can be satisfied without a photo.
public enum RecordStyle: String, CaseIterable, Sendable {
    /// Tidying: a photo before and one after (or a word on what was tidied).
    case beforeAfter
    /// Cooking, making things: a photo of the result (or a word).
    case result
    /// Exercise, study: how much was done (reps, minutes, pages…), optionally a photo while doing it.
    case amount
    /// Resting: a word on how it felt.
    case feeling

    public static func style(forQuestTitled title: String, in category: GoalCategory) -> RecordStyle {
        let lowered = title.lowercased()
        for (style, words) in keywords where words.contains(where: { lowered.contains($0) }) {
            return style
        }
        switch category {
        case .tidy: return .beforeAfter
        case .create, .other: return .result
        case .move, .study: return .amount
        case .rest: return .feeling
        }
    }

    /// Checked in this order, so "片付けながら筋トレ" counts as tidying.
    static let keywords: [(RecordStyle, [String])] = [
        (.beforeAfter, ["片付", "かたづけ", "掃除", "そうじ", "整理", "戻す", "ゴミ", "tidy", "clean", "declutter"]),
        (.result, ["料理", "ご飯", "ごはん", "作る", "つくる", "描", "cook", "bake", "make", "draw"]),
        (
            .amount,
            [
                "筋トレ", "腕立て", "腹筋", "スクワット", "走", "歩", "ストレッチ", "読", "ページ", "単語", "問題", "勉強",
                "workout", "push", "squat", "run", "walk", "stretch", "read", "page", "word", "study",
            ]
        ),
        (.feeling, ["休", "深呼吸", "眠", "寝", "rest", "breath", "sleep", "nap"]),
    ]

    /// Unit offered first when entering an amount.
    public func defaultUnit(forQuestTitled title: String) -> AmountUnit {
        let lowered = title.lowercased()
        if ["ページ", "読", "page", "read"].contains(where: { lowered.contains($0) }) { return .pages }
        if ["問題", "単語", "problem", "word"].contains(where: { lowered.contains($0) }) { return .items }
        if ["腕立て", "腹筋", "スクワット", "push", "squat", "sit-up"].contains(where: { lowered.contains($0) }) {
            return .times
        }
        return .minutes
    }
}

public enum AmountUnit: String, CaseIterable, Sendable {
    case minutes
    case times
    case pages
    case items
}

/// A self-reported amount ("20回", "15分"). Self-reported on purpose: it is a diary, not proof.
public struct TaskAmount: Equatable, Sendable {
    public static let valueRange = 1...999

    public let value: Int
    public let unit: AmountUnit

    /// `nil` outside the allowed range.
    public init?(value: Int, unit: AmountUnit) {
        guard Self.valueRange.contains(value) else { return nil }
        self.value = value
        self.unit = unit
    }
}

/// What was recorded when a quest was finished, and whether it is the record its style asks for.
public struct RecordCheck: Equatable, Sendable {
    public let style: RecordStyle
    public let hasBeforePhoto: Bool
    public let hasAfterPhoto: Bool
    public let amount: TaskAmount?
    public let note: String?

    public init(style: RecordStyle, hasBeforePhoto: Bool, hasAfterPhoto: Bool, amount: TaskAmount?, note: String?) {
        self.style = style
        self.hasBeforePhoto = hasBeforePhoto
        self.hasAfterPhoto = hasAfterPhoto
        self.amount = amount
        let trimmed = note?.trimmingCharacters(in: .whitespacesAndNewlines)
        self.note = (trimmed?.isEmpty ?? true) ? nil : trimmed
    }

    /// The record fits the style. Each style has a way to complete it without a camera (ADR-0015).
    public var isComplete: Bool {
        switch style {
        case .beforeAfter: (hasBeforePhoto && hasAfterPhoto) || note != nil
        case .result: hasAfterPhoto || note != nil
        case .amount: amount != nil
        case .feeling: note != nil
        }
    }

    /// Nothing at all was recorded (finishing still counts; there is just nothing to keep).
    public var isEmpty: Bool { !hasBeforePhoto && !hasAfterPhoto && amount == nil && note == nil }
}
