import AppIntents
import Foundation
import HibimachiCore
import WidgetKit

/// The widget's "やった！": completes one of today's quests with the same reward rules as the app.
struct CompleteQuestIntent: AppIntent {
    static var title: LocalizedStringResource { "クエストをやった！にする" }
    static var isDiscoverable: Bool { false }

    @Parameter(title: "クエスト") var questID: String

    init() {}

    init(questID: UUID) {
        self.questID = questID.uuidString
    }

    func perform() async throws -> some IntentResult {
        if let id = UUID(uuidString: questID), let repository = SharedContainer.sharedRepository {
            // A refused completion (already done, quest removed) simply leaves the save as it is; the widget
            // reloads after the intent and shows the current state.
            QuickQuestCompletion.complete(id, repository: repository, at: Date())
        }
        return .result()
    }
}
