import Foundation
import os

/// A tiny additive synthesizer: short notes with an attack/decay envelope, mixed into one mono stream.
/// The game's sounds are generated in code (no audio files), like its art. `render` runs on the audio thread;
/// voices are handed over through a lock, so callers may add notes from any thread.
final class Synth: Sendable {
    enum Wave: Sendable {
        /// Soft round tone (sine with a little second harmonic): bells, music.
        case bell
        /// Brighter pluck (triangle): clicks and placements.
        case pluck
    }

    struct Voice: Sendable {
        var frequency: Double
        var amplitude: Double
        var wave: Wave
        var attackFrames: Double
        var decayFrames: Double
        var phase: Double = 0
        var age: Double = 0

        var isFinished: Bool { age > attackFrames + decayFrames * 6 }

        mutating func nextSample(sampleRate: Double) -> Double {
            let envelope =
                age < attackFrames ? age / max(attackFrames, 1) : exp(-(age - attackFrames) / max(decayFrames, 1))
            let value: Double
            switch wave {
            case .bell: value = sin(phase) + 0.25 * sin(2 * phase)
            case .pluck: value = 2 / .pi * asin(sin(phase))
            }
            phase += 2 * .pi * frequency / sampleRate
            if phase > 2 * .pi { phase -= 2 * .pi }
            age += 1
            return value * envelope * amplitude
        }
    }

    let sampleRate: Double
    private let voices = OSAllocatedUnfairLock(initialState: [Voice]())
    /// More simultaneous voices than this drop the oldest, so a burst of events cannot pile up.
    static let maxVoices = 24

    init(sampleRate: Double) {
        self.sampleRate = sampleRate
    }

    func play(_ frequency: Double, amplitude: Double, attack: Double = 0.005, decay: Double, wave: Wave = .bell) {
        let voice = Voice(
            frequency: frequency, amplitude: amplitude, wave: wave, attackFrames: attack * sampleRate,
            decayFrames: decay * sampleRate)
        voices.withLock { current in
            current.append(voice)
            if current.count > Self.maxVoices { current.removeFirst(current.count - Self.maxVoices) }
        }
    }

    var activeVoices: Int { voices.withLock { $0.count } }

    /// Fills `frames` samples (mono) and drops finished voices. Output is soft-clipped to -1...1.
    func render(into buffer: UnsafeMutableBufferPointer<Float>, frames: Int) {
        voices.withLock { current in
            for frame in 0..<min(frames, buffer.count) {
                var sample = 0.0
                for index in current.indices { sample += current[index].nextSample(sampleRate: sampleRate) }
                buffer[frame] = Float(tanh(sample))
            }
            current.removeAll { $0.isFinished }
        }
    }
}
