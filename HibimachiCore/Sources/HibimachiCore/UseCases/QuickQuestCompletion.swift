import Foundation

public enum QuickCompletionError: Error, Equatable, Sendable {
    /// There is no readable save yet; the app has to be opened first.
    case noSave
    case progress(ProgressError)
    case saveFailed(String)
}

/// Completes a quest without the island screen (the widget's "やった！" button).
///
/// Unlike `GameStore`, this never creates a new island or moves an unreadable save aside: it only edits a save
/// that already loads, with the same reward rules (once per quest per day, one reward per completion).
public enum QuickQuestCompletion {
    @discardableResult
    public static func complete(
        _ questID: UUID,
        repository: any WorldRepository,
        at date: Date,
        calendar: Calendar = .current,
        makeID: () -> UUID = UUID.init
    ) -> Result<RewardTransaction, QuickCompletionError> {
        guard var snapshot = repository.peek() else { return .failure(.noSave) }
        let day = LocalDay(date: date, calendar: calendar)
        let result = snapshot.progress.complete(
            questID, on: day, at: date, completionID: makeID(), transactionID: makeID())
        switch result {
        case .failure(let error):
            return .failure(.progress(error))
        case .success(let reward):
            do {
                try repository.save(snapshot)
                return .success(reward)
            } catch {
                return .failure(.saveFailed(String(describing: error)))
            }
        }
    }
}
