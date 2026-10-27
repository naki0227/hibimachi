import Foundation

/// Where a photo taken during a session goes.
public enum SessionPhotoSlot: Sendable {
    case before
    case during
}

/// What finishing a quest produced, for the "やった！" card and the coach.
public struct FinishedTask: Equatable, Sendable {
    public let completionID: UUID
    public let questTitle: String
    public let check: RecordCheck
    /// The album entry holding the record (`nil` when nothing was recorded).
    public let entryID: UUID?
    public let bonus: RewardTransaction?
}

/// "今からやる → おわった" (ADR-0015): start a quest, take photos that fit it, then finish it with a record.
/// Everything recorded is optional; finishing always counts as doing the quest.
extension GameStore {
    public var activeSession: TaskSession? { album.session }

    /// How a quest is recorded: rules on its title and its goal's category.
    public func recordStyle(of quest: QuestTemplate) -> RecordStyle {
        let category = progress.goals.first { $0.id == quest.goalID }?.category ?? .other
        return RecordStyle.style(forQuestTitled: quest.title, in: category)
    }

    public func quest(_ id: UUID) -> QuestTemplate? { progress.quests.first { $0.id == id } }

    /// Starts a quest. Refused while another one is in progress or when it is already done today.
    @discardableResult
    public func startTask(_ questID: UUID) -> Bool {
        guard album.session == nil, quest(questID) != nil, !progress.isCompleted(questID, on: today) else {
            return false
        }
        updateAlbum { $0.session = TaskSession(questID: questID, startedAt: nowForProgress) }
        return true
    }

    /// Keeps a photo for the running session, replacing (and deleting) the previous one in that slot.
    @discardableResult
    public func attachSessionPhoto(_ jpeg: Data, to slot: SessionPhotoSlot) -> Bool {
        guard album.session != nil else { return false }
        guard let media else {
            setAlbumError(.photoUnavailable)
            return false
        }
        let reference: MediaReference
        do {
            reference = try media.savePhoto(jpeg, id: makeIDForProgress(), at: nowForProgress)
        } catch {
            setAlbumError(.photoSaveFailed(String(describing: error)))
            return false
        }
        var replaced: MediaReference?
        updateAlbum { album in
            switch slot {
            case .before:
                replaced = album.session?.beforePhoto
                album.session?.beforePhoto = reference
            case .during:
                replaced = album.session?.duringPhoto
                album.session?.duringPhoto = reference
            }
        }
        if let replaced, saveErrorMessage == nil { try? media.delete(replaced) }
        setAlbumError(nil)
        return true
    }

    /// Stops without doing the quest; photos taken for it are deleted.
    public func cancelTask() {
        guard let session = album.session else { return }
        updateAlbum { $0.session = nil }
        if saveErrorMessage == nil { session.photos.forEach { try? media?.delete($0) } }
    }

    /// Finishes the running quest: rewards it, keeps whatever was recorded and adds the record bonus when the
    /// record fits the quest (`RecordCheck`). `nil` when there is no session or the quest cannot be completed.
    @discardableResult
    public func finishTask(afterJPEG: Data? = nil, amount: TaskAmount? = nil, note: String? = nil) -> FinishedTask? {
        guard let session = album.session, let quest = quest(session.questID) else { return nil }
        // Checked first so an over-long note cannot leave a saved photo without an entry.
        if let note, note.trimmingCharacters(in: .whitespacesAndNewlines).count > Album.textLimit {
            setAlbumError(.textTooLong(limit: Album.textLimit))
            return nil
        }
        var afterPhoto: MediaReference?
        if let afterJPEG {
            guard let media else {
                setAlbumError(.photoUnavailable)
                return nil
            }
            do {
                afterPhoto = try media.savePhoto(afterJPEG, id: makeIDForProgress(), at: nowForProgress)
            } catch {
                setAlbumError(.photoSaveFailed(String(describing: error)))
                return nil
            }
        }
        guard completeQuest(quest.id), let completionID = lastCompletion?.completionID else {
            // Already done today or removed meanwhile: end the session instead of leaving it stuck.
            if let afterPhoto { try? media?.delete(afterPhoto) }
            cancelTask()
            return nil
        }
        let check = RecordCheck(
            style: recordStyle(of: quest), hasBeforePhoto: session.beforePhoto != nil,
            hasAfterPhoto: afterPhoto != nil, amount: amount, note: note)
        let entryID = keepRecord(session: session, after: afterPhoto, check: check, completionID: completionID)
        var bonus: RewardTransaction?
        if check.isComplete {
            updateProgress { progress in
                bonus = try? progress.grantRecordBonus(
                    for: completionID, check: check, at: nowForProgress, transactionID: makeIDForProgress()
                ).get()
            }
        }
        return FinishedTask(
            completionID: completionID, questTitle: quest.title, check: check, entryID: entryID, bonus: bonus)
    }

    /// Adds the coach's comment to a finished task's entry (it arrives after finishing).
    public func setCoachComment(_ comment: String, on entryID: UUID) {
        updateAlbum { $0.setComment(comment, on: entryID) }
    }

    /// Writes the album entries for a finished session and ends it. Returns the main entry's ID.
    private func keepRecord(
        session: TaskSession, after: MediaReference?, check: RecordCheck, completionID: UUID
    ) -> UUID? {
        var mainID: UUID?
        updateAlbum { album in
            album.session = nil
            var beforeID: UUID?
            if let before = session.beforePhoto {
                let id = makeIDForProgress()
                if case .success = album.add(
                    text: nil, photo: before, completionID: completionID, progress: progress, day: today,
                    at: session.startedAt, id: id)
                {
                    beforeID = id
                }
            }
            let photo = after ?? session.duringPhoto
            guard photo != nil || check.amount != nil || check.note != nil else {
                mainID = beforeID
                return
            }
            let id = makeIDForProgress()
            let result = album.add(
                text: check.note, photo: photo, completionID: completionID, progress: progress, day: today,
                at: nowForProgress, id: id, before: photo != nil ? beforeID : nil, amount: check.amount)
            mainID = (try? result.get()) != nil ? id : beforeID
        }
        // A during photo that became the entry's photo is kept; one replaced by an after photo is not needed.
        if after != nil, let during = session.duringPhoto, saveErrorMessage == nil { try? media?.delete(during) }
        return mainID
    }
}
