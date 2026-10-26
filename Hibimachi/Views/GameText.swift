import Foundation
import HibimachiCore

/// Player-facing copy. Japanese is the source language; translations live in Shared/Localizable.xcstrings.
/// Kept in the app layer so domain types stay free of presentation text.
/// Bottom palette tabs (mockup: 建てる / かざる / みち / しぜん). "みち" is a painting tool, not an object.
enum PaletteTab: String, CaseIterable, Identifiable {
    case build
    case decor
    case path
    case nature

    var id: String { rawValue }

    var title: String {
        switch self {
        case .build: String(localized: "建てる")
        case .decor: String(localized: "かざる")
        case .path: String(localized: "みち")
        case .nature: String(localized: "しぜん")
        }
    }

    var symbolName: String {
        switch self {
        case .build: "house"
        case .decor: "sparkles"
        case .path: "road.lanes"
        case .nature: "leaf"
        }
    }

    var kinds: [ObjectKind] {
        switch self {
        case .build: [.house, .bench, .fence, .mailbox, .swing, .well, .cafe]
        case .decor: [.lamp, .flower, .picnicMat, .birdhouse, .campfire, .fountain]
        case .path: []
        case .nature: [.roundTree, .pineTree, .sakuraTree, .bush, .rock, .flower, .pond, .garden]
        }
    }
}

extension DayPhase {
    var title: String {
        switch self {
        case .morning: String(localized: "朝")
        case .day: String(localized: "昼")
        case .evening: String(localized: "夕方")
        case .night: String(localized: "夜")
        }
    }

    var symbolName: String {
        switch self {
        case .morning: "sunrise.fill"
        case .day: "sun.max.fill"
        case .evening: "sunset.fill"
        case .night: "moon.stars.fill"
        }
    }
}

extension PlacementError {
    var message: String {
        switch self {
        case .outOfBounds: String(localized: "島の外には置けません")
        case .blockedByTerrain(.water): String(localized: "水の上には置けません")
        case .blockedByTerrain(.path): String(localized: "小道の上には置けません")
        case .blockedByTerrain(.grass): String(localized: "この地面には置けません")
        case .overlapsObject: String(localized: "ほかのものと重なっています")
        case .unknownObject: String(localized: "動かすものが見つかりません")
        }
    }
}

extension GoalCategory {
    var title: String {
        switch self {
        case .tidy: String(localized: "片付け")
        case .study: String(localized: "学び")
        case .rest: String(localized: "休息")
        case .create: String(localized: "創作")
        case .move: String(localized: "からだ")
        case .other: String(localized: "そのほか")
        }
    }

    /// Suggested goal name when the player picks a category (editable).
    var defaultGoalTitle: String {
        switch self {
        case .tidy: String(localized: "部屋を心地よくする")
        case .study: String(localized: "少しずつ学ぶ")
        case .rest: String(localized: "ちゃんと休む")
        case .create: String(localized: "つくる時間を持つ")
        case .move: String(localized: "からだを動かす")
        case .other: String(localized: "気になることを進める")
        }
    }

    var symbolName: String {
        switch self {
        case .tidy: "sparkles"
        case .study: "book"
        case .rest: "cup.and.saucer"
        case .create: "paintbrush.pointed"
        case .move: "figure.walk"
        case .other: "star"
        }
    }
}

extension ProgressError {
    var message: String {
        switch self {
        case .emptyTitle: String(localized: "名前を入れてください")
        case .titleTooLong(let limit): String(localized: "\(limit)文字までにしてください")
        case .tooManyGoals(let limit): String(localized: "目標は\(limit)つまでです。どれかを「おやすみ」にすると追加できます")
        case .unknownGoal, .unknownQuest, .unknownCompletion: String(localized: "見つかりませんでした。もう一度ためしてください")
        case .goalArchived: String(localized: "おやすみ中の目標です")
        case .alreadyCompletedToday: String(localized: "今日はもう記録済みです")
        case .alreadyRewarded: String(localized: "この記録はもう受け取り済みです")
        case .undoOnlySameDay: String(localized: "取り消せるのは当日の記録だけです")
        case .notEnoughSparkles(let needed, let balance): String(localized: "きらめきが足りません（\(balance) / \(needed)）")
        case .invalidMinutes: String(localized: "時間は1〜60分にしてください")
        case .duplicateID, .negativeBalance: String(localized: "記録に問題があります")
        }
    }
}

extension QuestPresets.Language {
    /// The language the app is shown in, so preset quests match the rest of the UI.
    static var current: Self {
        Bundle.main.preferredLocalizations.first == "en" ? .english : .japanese
    }
}
