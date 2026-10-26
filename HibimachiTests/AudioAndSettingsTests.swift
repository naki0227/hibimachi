import Foundation
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
        #expect(settings.soundEffects && settings.music && settings.haptics)
        settings.music = false
        settings.haptics = false
        let reloaded = AppSettings(defaults: defaults)
        #expect(reloaded.soundEffects && !reloaded.music && !reloaded.haptics)
    }
}
