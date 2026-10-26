import Foundation

/// Plumbing for the progress and album extensions: every change goes through here so it is saved once.
extension GameStore {
    var makeIDForProgress: () -> UUID { makeID }
    var nowForProgress: Date { now() }

    /// Mutates progress; saves only if something actually changed.
    func updateProgress(_ change: (inout PlayerProgress) -> Void) {
        var copy = progress
        change(&copy)
        guard copy != progress else { return }
        progress = copy
        growIslandIfDue()
        persist()
    }

    func setLastCompletion(_ value: (completionID: UUID, reward: RewardTransaction)?) {
        lastCompletion = value
    }

    func recordProgressError(_ error: ProgressError) { lastProgressError = error }

    /// Mutates the album and saves (used by GameStore+Album).
    func updateAlbum(_ change: (inout Album) -> Void) {
        var copy = album
        change(&copy)
        guard copy != album else { return }
        album = copy
        persist()
    }

    func setAlbumError(_ error: AlbumError?) { lastAlbumError = error }
    func clearProgressError() { lastProgressError = nil }
}
