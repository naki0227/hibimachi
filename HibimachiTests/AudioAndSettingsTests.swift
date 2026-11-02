import Foundation
import HibimachiCore
import Testing

@testable import Hibimachi

@Suite("Generated sound")
struct SynthTests {
    @Test func notesSoundThenFadeOutAndAreDropped() {
        let synth = Synth(sampleRate: 8_000)
        var buffer = [Float](repeating: 0, count: 800)
        synth.play(440, amplitude: 0.5, decay: 0.01)
        #expect(synth.activeVoices == 1)
        buffer.withUnsafeMutableBufferPointer { synth.render(into: $0, frames: 800) }
        #expect(buffer.contains { abs($0) > 0.05 }, "the note is audible")
        #expect(buffer.allSatisfy { abs($0) <= 1 }, "soft-clipped")
        buffer.withUnsafeMutableBufferPointer { synth.render(into: $0, frames: 800) }
        #expect(synth.activeVoices == 0, "finished voices are removed")
        #expect(buffer.allSatisfy { abs($0) < 0.01 })
    }

    @Test func aBurstOfNotesIsCapped() {
        let synth = Synth(sampleRate: 8_000)
        for _ in 0..<100 { synth.play(440, amplitude: 0.1, decay: 1) }
        #expect(synth.activeVoices == Synth.maxVoices)
    }
}

@MainActor
@Suite("Settings")
struct AppSettingsTests {
    @Test func defaultsAreOnAndChangesPersist() throws {
        let name = "settings-test-\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: name))
        defer { defaults.removePersistentDomain(forName: name) }
        let settings = AppSettings(defaults: defaults)
        #expect(settings.soundEffects && settings.music && settings.haptics && settings.aiCoach)
        settings.music = false
        settings.haptics = false
        settings.aiCoach = false
        let reloaded = AppSettings(defaults: defaults)
        #expect(reloaded.soundEffects && !reloaded.music && !reloaded.haptics && !reloaded.aiCoach)
    }
}

@MainActor
@Suite("Task coach")
struct TaskCoachTests {
    private func finished(_ check: RecordCheck) -> FinishedTask {
        FinishedTask(completionID: UUID(), questTitle: "腕立て伏せ", check: check, entryID: nil, bonus: nil)
    }

    @Test func thePromptHoldsOnlyWhatWasRecorded() throws {
        let amount = try #require(TaskAmount(value: 20, unit: .times))
        let check = RecordCheck(
            style: .amount, hasBeforePhoto: false, hasAfterPhoto: false, amount: amount, note: "きつかった")
        let prompt = TaskCoach.prompt(for: finished(check), labels: ["person"])
        #expect(prompt.contains("腕立て伏せ") && prompt.contains("20 times") && prompt.contains("きつかった"))
        #expect(prompt.contains("person"))
        let bare = TaskCoach.prompt(
            for: finished(
                RecordCheck(style: .amount, hasBeforePhoto: false, hasAfterPhoto: false, amount: nil, note: nil)),
            labels: [])
        #expect(bare.split(separator: "\n").count == 1, "only the task when nothing was recorded")
    }

    @Test func withoutAITheRuleLineIsUsed() async throws {
        let store = GameStore(repository: MemoryRepository(), seed: 1)
        let check = RecordCheck(style: .feeling, hasBeforePhoto: false, hasAfterPhoto: false, amount: nil, note: "すっきり")
        let comment = await TaskCoach.comment(for: finished(check), in: store, aiAllowed: false)
        #expect(comment == check.ruleText)
        #expect(!comment.isEmpty)
    }
}

@MainActor
@Suite("Plan coach")
struct PlanCoachTests {
    private let goal = Goal(id: UUID(), title: "部屋を心地よく", category: .tidy, createdAt: Date())

    @Test func withoutAITheCategoryTemplateIsOffered() async {
        let result = await PlanCoach.draft(for: goal, aiAllowed: false)
        #expect(!result.byAI)
        #expect(result.draft == PlanDraft.template(for: .tidy, language: .current))
    }

    @Test func thePromptHoldsOnlyTheGoal() {
        #expect(PlanCoach.prompt(for: goal) == "goal: 部屋を心地よく\ncategory: tidy")
    }
}
