import Foundation

/// A quest the player said they are doing now ("今からやる"), with the photos taken so far (ADR-0015).
/// One at a time; finishing or cancelling ends it.
public struct TaskSession: Equatable, Sendable {
    public let questID: UUID
    public let startedAt: Date
    /// "Where will you tidy?" — taken when starting (before / after quests).
    public internal(set) var beforePhoto: MediaReference?
    /// While doing it (exercise, study…). Optional.
    public internal(set) var duringPhoto: MediaReference?

    public init(questID: UUID, startedAt: Date, beforePhoto: MediaReference? = nil, duringPhoto: MediaReference? = nil)
    {
        self.questID = questID
        self.startedAt = startedAt
        self.beforePhoto = beforePhoto
        self.duringPhoto = duringPhoto
    }

    public var photos: [MediaReference] { [beforePhoto, duringPhoto].compactMap { $0 } }
}
