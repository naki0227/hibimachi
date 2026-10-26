import AVFoundation
import HibimachiCore

/// Plays the game's generated sounds: short effects for actions and a quiet, wandering pentatonic tune.
/// Uses the ambient audio category, so it respects the silent switch and mixes with the player's music.
@MainActor
final class SoundPlayer {
    enum Effect {
        case place
        case path
        case undo
        case refuse
        case questDone
        case discovery
        case arrival
        case tap
    }

    static let shared = SoundPlayer()

    var effectsEnabled = true
    var musicEnabled = true {
        didSet { musicEnabled ? startMusic() : stopMusic() }
    }
    /// Evening/night play lower and slower.
    var calm = false

    private let engine = AVAudioEngine()
    private let synth: Synth
    private var started = false
    private var musicTimer: Timer?
    private var step = 0
    private var melodyIndex = 7

    // C major pentatonic over two octaves (C4…A5).
    private static let scale: [Double] = [
        261.63, 293.66, 329.63, 392.00, 440.00, 523.25, 587.33, 659.25, 783.99, 880.00,
    ]

    private init() {
        let format = AVAudioFormat(standardFormatWithSampleRate: 44_100, channels: 1)
        let rate = format?.sampleRate ?? 44_100
        let synth = Synth(sampleRate: rate)
        self.synth = synth
        let source = Self.makeSource(synth: synth)
        engine.attach(source)
        engine.connect(source, to: engine.mainMixerNode, format: format)
        engine.mainMixerNode.outputVolume = 0.8
    }

    /// Built outside the main actor: the render block runs on the real-time audio thread.
    private nonisolated static func makeSource(synth: Synth) -> AVAudioSourceNode {
        AVAudioSourceNode { _, _, frameCount, bufferList -> OSStatus in
            let buffers = UnsafeMutableAudioBufferListPointer(bufferList)
            guard let first = buffers.first, let data = first.mData else { return noErr }
            let samples = UnsafeMutableBufferPointer(
                start: data.assumingMemoryBound(to: Float.self), count: Int(frameCount))
            synth.render(into: samples, frames: Int(frameCount))
            for other in buffers.dropFirst() {
                other.mData?.copyMemory(from: data, byteCount: Int(first.mDataByteSize))
            }
            return noErr
        }
    }

    /// Starts or pauses audio with the app (no sound in the background).
    func setActive(_ active: Bool) {
        if active {
            guard !started else { return }
            do {
                try AVAudioSession.sharedInstance().setCategory(.ambient, options: [.mixWithOthers])
                try AVAudioSession.sharedInstance().setActive(true)
                try engine.start()
                started = true
                if musicEnabled { startMusic() }
            } catch {
                // No audio device (e.g. some simulators): the game simply stays silent.
                started = false
            }
        } else {
            stopMusic()
            engine.pause()
            started = false
        }
    }

    func play(_ effect: Effect) {
        guard effectsEnabled, started else { return }
        let s = Self.scale
        switch effect {
        case .place:
            synth.play(s[5], amplitude: 0.22, decay: 0.08, wave: .pluck)
            schedule(0.07) { $0.play(s[7], amplitude: 0.2, decay: 0.12, wave: .pluck) }
        case .path:
            synth.play(s[3] / 2, amplitude: 0.18, decay: 0.05, wave: .pluck)
        case .undo:
            synth.play(s[6], amplitude: 0.16, decay: 0.07, wave: .pluck)
            schedule(0.06) { $0.play(s[4], amplitude: 0.16, decay: 0.1, wave: .pluck) }
        case .refuse:
            synth.play(146.83, amplitude: 0.22, decay: 0.12, wave: .pluck)
        case .tap:
            synth.play(s[8], amplitude: 0.08, decay: 0.04, wave: .pluck)
        case .questDone:
            for (index, note) in [s[5], s[7], s[8], s[5] * 2].enumerated() {
                schedule(Double(index) * 0.08) { $0.play(note, amplitude: 0.2, decay: 0.35) }
            }
        case .discovery:
            for (index, note) in [s[9], s[7], s[9] * 1.5, s[9] * 2].enumerated() {
                schedule(Double(index) * 0.11) { $0.play(note, amplitude: 0.14, decay: 0.6) }
            }
        case .arrival:
            for (index, note) in [s[3], s[5], s[6], s[7], s[8], s[7]].enumerated() {
                schedule(Double(index) * 0.14) { $0.play(note, amplitude: 0.16, decay: 0.4) }
            }
        }
    }

    private func schedule(_ delay: Double, _ action: @escaping @Sendable (Synth) -> Void) {
        let synth = synth
        DispatchQueue.main.asyncAfter(deadline: .now() + delay) { action(synth) }
    }

    // MARK: Music

    private func startMusic() {
        guard started, musicTimer == nil else { return }
        musicTimer = Timer.scheduledTimer(withTimeInterval: 0.3, repeats: true) { _ in
            MainActor.assumeIsolated { SoundPlayer.shared.musicStep() }
        }
    }

    private func stopMusic() {
        musicTimer?.invalidate()
        musicTimer = nil
    }

    /// One 0.3 s step of a slow random walk on the pentatonic scale, with a soft low chord every 16 steps.
    private func musicStep() {
        step += 1
        let s = Self.scale
        let octave = calm ? 0.5 : 1.0
        if step % 16 == 1 {
            let root = [0, 3, 4, 1][(step / 16) % 4]
            synth.play(s[root] / 2 * octave, amplitude: 0.05, attack: 0.3, decay: 1.6)
            synth.play(s[root + 2] / 2 * octave, amplitude: 0.035, attack: 0.3, decay: 1.6)
        }
        let every = calm ? 3 : 2
        guard step % every == 0, Double.random(in: 0...1) < 0.6 else { return }
        melodyIndex = min(max(melodyIndex + Int.random(in: -2...2), 3), s.count - 1)
        synth.play(s[melodyIndex] * octave, amplitude: 0.045, attack: 0.01, decay: calm ? 0.9 : 0.6)
    }
}
