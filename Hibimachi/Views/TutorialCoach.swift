import HibimachiCore
import Observation
import SwiftUI

/// Holds the first-run guide for one save and remembers its step in UserDefaults. The step is not game data,
/// so it stays out of the save file (and the widget never sees it).
@MainActor
@Observable
final class TutorialCoach {
    private(set) var guide: TutorialGuide
    @ObservationIgnored private let defaults: UserDefaults
    @ObservationIgnored private let key: String

    init(storageName: String, enabled: Bool, defaults: UserDefaults = .standard) {
        self.defaults = defaults
        key = "tutorial.step.\(storageName)"
        guide =
            enabled
            ? TutorialGuide(rawStep: defaults.object(forKey: key) as? Int) : TutorialGuide(step: .finished)
    }

    func record(_ signal: TutorialGuide.Signal, store: GameStore) {
        update {
            $0.record(signal)
            $0.catchUp(hasDiscoveries: !store.world.discoveries.isEmpty, hasGoals: !store.progress.activeGoals.isEmpty)
        }
    }

    func catchUp(store: GameStore) {
        update {
            $0.catchUp(hasDiscoveries: !store.world.discoveries.isEmpty, hasGoals: !store.progress.activeGoals.isEmpty)
        }
    }

    func skip() {
        update { $0.skip() }
    }

    /// From the settings panel: show the guide again, skipping steps the player has already done.
    func restart(store: GameStore) {
        update {
            $0 = TutorialGuide()
            $0.catchUp(hasDiscoveries: !store.world.discoveries.isEmpty, hasGoals: !store.progress.activeGoals.isEmpty)
        }
    }

    private func update(_ change: (inout TutorialGuide) -> Void) {
        var copy = guide
        change(&copy)
        guard copy != guide else { return }
        guide = copy
        defaults.set(copy.step.rawValue, forKey: key)
    }
}

/// Watches the store for what each step asks for. Attached to the island screen.
struct TutorialSignals: ViewModifier {
    let store: GameStore
    let coach: TutorialCoach

    func body(content: Content) -> some View {
        content
            .onAppear { coach.catchUp(store: store) }
            .onChange(of: store.world.objects.count) { old, new in
                if new > old { coach.record(.placedObject, store: store) }
            }
            .onChange(of: store.world.discoveries.count) { old, new in
                if new > old { coach.record(.discovered, store: store) }
            }
            .onChange(of: store.progress.activeGoals.count) { old, new in
                if new > old { coach.record(.createdGoal, store: store) }
            }
            .sensoryFeedback(.success, trigger: coach.guide.step) { _, new in new == .finished }
    }
}

/// The hint shown above the bottom bar.
struct TutorialCard: View {
    let step: TutorialGuide.Step
    let skip: () -> Void

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Text("\(step.rawValue + 1)/\(TutorialGuide.stepCount)")
                .font(GameFont.body(12, weight: .heavy))
                .foregroundStyle(.white)
                .frame(width: 36, height: 36)
                .background(GameColor.leaf, in: Circle())
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(GameFont.body(15, weight: .heavy)).foregroundStyle(GameColor.ink)
                Text(message)
                    .font(GameFont.body(12, weight: .medium))
                    .foregroundStyle(GameColor.inkSoft)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 0)
            Button("とばす", action: skip)
                .buttonStyle(.game(.secondary, compact: true))
                .accessibilityLabel("案内をとばす")
        }
        .padding(12)
        .background(GameColor.paper, in: RoundedRectangle(cornerRadius: 20))
        .overlay(RoundedRectangle(cornerRadius: 20).stroke(GameColor.leaf.opacity(0.6), lineWidth: 2.5))
        .shadow(color: GameColor.ink.opacity(0.18), radius: 6, y: 3)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("tutorial-card")
    }

    private var title: String {
        switch step {
        case .place: String(localized: "島に、ひとつ置いてみよう")
        case .discover: String(localized: "生き物のようすを見てみよう")
        case .quests: String(localized: "きょうのことを始めよう")
        case .finished: ""
        }
    }

    private var message: String {
        switch step {
        case .place: String(localized: "下のパレットから選んで、置きたい場所で「ここに置く」。")
        case .discover: String(localized: "ベンチや木のそばで、生き物が何かをするかも。見つけると「発見！」になります。")
        case .quests: String(localized: "右の ✓ ボタンから目標をえらぶと、小さなクエストで きらめき がもらえます。")
        case .finished: ""
        }
    }
}

/// Soft pulsing ring that points at the button a tutorial step talks about.
struct TutorialPulse: ViewModifier {
    let active: Bool
    @State private var expanded = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func body(content: Content) -> some View {
        content.overlay {
            if active {
                Circle()
                    .stroke(GameColor.sun, lineWidth: 4)
                    .scaleEffect(expanded && !reduceMotion ? 1.25 : 1.05)
                    .opacity(expanded && !reduceMotion ? 0.2 : 0.9)
                    .allowsHitTesting(false)
                    .onAppear {
                        withAnimation(.easeInOut(duration: 0.9).repeatForever(autoreverses: true)) { expanded = true }
                    }
            }
        }
    }
}
