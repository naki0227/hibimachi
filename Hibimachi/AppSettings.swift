import Foundation
import Observation

/// Player preferences (not game data, so they live in UserDefaults rather than the save file).
@MainActor
@Observable
final class AppSettings {
    var soundEffects: Bool {
        didSet { store(soundEffects, Keys.effects) }
    }
    var music: Bool {
        didSet { store(music, Keys.music) }
    }
    var haptics: Bool {
        didSet { store(haptics, Keys.haptics) }
    }

    @ObservationIgnored private let defaults: UserDefaults

    private enum Keys {
        static let effects = "settings.soundEffects"
        static let music = "settings.music"
        static let haptics = "settings.haptics"
    }

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        soundEffects = defaults.object(forKey: Keys.effects) as? Bool ?? true
        music = defaults.object(forKey: Keys.music) as? Bool ?? true
        haptics = defaults.object(forKey: Keys.haptics) as? Bool ?? true
    }

    private func store(_ value: Bool, _ key: String) {
        defaults.set(value, forKey: key)
    }
}
