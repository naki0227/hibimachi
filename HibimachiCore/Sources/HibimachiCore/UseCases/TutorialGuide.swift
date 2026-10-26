import Foundation

/// The first-run guide: place something, see a reaction, then try today's quests. Three hints, each can be
/// skipped, and steps the player already did on their own are not asked again.
public struct TutorialGuide: Equatable, Sendable {
    public enum Step: Int, CaseIterable, Sendable {
        case place
        case discover
        case quests
        case finished
    }

    /// Things the player did, reported by the screen.
    public enum Signal: Sendable {
        case placedObject
        case discovered
        case createdGoal
    }

    public private(set) var step: Step

    public init(step: Step = .place) {
        self.step = step
    }

    /// Restores a saved step; unknown values (e.g. from a newer build) count as finished.
    public init(rawStep: Int?) {
        self.step = rawStep.map { Step(rawValue: $0) ?? .finished } ?? .place
    }

    public var isActive: Bool { step != .finished }

    /// 1-based position for "1/3" labels.
    public var number: Int { step.rawValue + 1 }
    public static let stepCount = Step.allCases.count - 1

    public mutating func record(_ signal: Signal) {
        switch (step, signal) {
        case (.place, .placedObject), (.discover, .discovered), (.quests, .createdGoal):
            step = Step(rawValue: step.rawValue + 1) ?? .finished
        default:
            break
        }
    }

    /// Skips steps whose goal is already reached (a reaction that happened before its hint, a goal made early).
    public mutating func catchUp(hasDiscoveries: Bool, hasGoals: Bool) {
        if step == .discover, hasDiscoveries { step = .quests }
        if step == .quests, hasGoals { step = .finished }
    }

    public mutating func skip() {
        step = .finished
    }
}
