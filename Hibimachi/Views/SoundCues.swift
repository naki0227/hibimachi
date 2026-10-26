import HibimachiCore
import SwiftUI

/// Turns store changes into sound effects, keeps the player's settings in the sound player, and moves the
/// music to a calmer mode in the evening. Attached to the island screen; holds no game rules.
struct SoundCues: ViewModifier {
    let store: GameStore
    let settings: AppSettings
    let phase: DayPhase

    private var sound: SoundPlayer { SoundPlayer.shared }

    func body(content: Content) -> some View {
        content
            .onAppear {
                sound.effectsEnabled = settings.soundEffects
                sound.musicEnabled = settings.music
                sound.calm = phase.lightsOn
                // The scene may already be active at launch, so do not wait for a scenePhase change.
                sound.setActive(true)
            }
            .onChange(of: settings.soundEffects) { _, on in sound.effectsEnabled = on }
            .onChange(of: settings.music) { _, on in sound.musicEnabled = on }
            .onChange(of: phase) { _, phase in sound.calm = phase.lightsOn }
            .onChange(of: store.objectsRevision) { sound.play(.place) }
            .onChange(of: store.terrainRevision) { sound.play(.path) }
            .onChange(of: store.lastRejection) { _, rejection in if rejection != nil { sound.play(.refuse) } }
            .onChange(of: store.lastCompletion?.completionID) { _, id in if id != nil { sound.play(.questDone) } }
            .onChange(of: store.pendingDiscoveries.count) { old, new in if new > old { sound.play(.discovery) } }
            .onChange(of: store.pendingArrivals.count) { old, new in if new > old { sound.play(.arrival) } }
    }
}
