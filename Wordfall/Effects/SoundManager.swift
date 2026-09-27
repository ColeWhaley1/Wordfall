import AVFoundation

/// Synthesised sound effects. Every sound is generated in code at launch, so
/// the game ships without audio assets and the sounds are easy to tweak.
/// Uses the ambient session category: respects the silent switch and mixes
/// with the player's music.
@MainActor
final class SoundManager {
    enum Effect: CaseIterable {
        case pop, chime, rise, thud, buzz, warning, levelUp
    }

    var isEnabled = true

    private let engine = AVAudioEngine()
    private var players: [AVAudioPlayerNode] = []
    private var nextPlayer = 0
    private var effects: [Effect: AVAudioPCMBuffer] = [:]
    /// Selection ticks rise in pitch with each letter.
    private var ticks: [AVAudioPCMBuffer] = []
    private let format: AVAudioFormat
    private var sessionConfigured = false

    private static let sampleRate = 44_100.0

    init() {
        format = AVAudioFormat(standardFormatWithSampleRate: Self.sampleRate, channels: 1)!
        for _ in 0..<6 {
            let player = AVAudioPlayerNode()
            engine.attach(player)
            engine.connect(player, to: engine.mainMixerNode, format: format)
            players.append(player)
        }
        for effect in Effect.allCases {
            effects[effect] = Self.render(duration: Self.duration(of: effect), format: format, sample: Self.generator(for: effect))
        }
        for step in 0..<10 {
            let frequency = 900 * pow(1.0595, Double(step * 2))
            if let buffer = Self.render(duration: 0.05, format: format, sample: { t in
                sin(2 * .pi * frequency * t) * exp(-t * 80) * 0.28
            }) {
                ticks.append(buffer)
            }
        }
    }

    func play(_ effect: Effect) {
        guard let buffer = effects[effect] else { return }
        schedule(buffer)
    }

    func tick(step: Int) {
        guard !ticks.isEmpty else { return }
        schedule(ticks[min(max(step, 0), ticks.count - 1)])
    }

    private func schedule(_ buffer: AVAudioPCMBuffer) {
        guard isEnabled, startIfNeeded() else { return }
        let player = players[nextPlayer]
        nextPlayer = (nextPlayer + 1) % players.count
        player.scheduleBuffer(buffer, at: nil, options: .interrupts, completionHandler: nil)
        if !player.isPlaying {
            player.play()
        }
    }

    private func startIfNeeded() -> Bool {
        if engine.isRunning { return true }
        do {
            if !sessionConfigured {
                try AVAudioSession.sharedInstance().setCategory(.ambient, mode: .default)
                try AVAudioSession.sharedInstance().setActive(true)
                sessionConfigured = true
            }
            try engine.start()
            return true
        } catch {
            return false
        }
    }

    // MARK: Synthesis

    private static func duration(of effect: Effect) -> Double {
        switch effect {
        case .pop: return 0.2
        case .chime: return 0.45
        case .rise: return 0.5
        case .thud: return 0.35
        case .buzz: return 0.16
        case .warning: return 0.22
        case .levelUp: return 0.5
        }
    }

    private static func generator(for effect: Effect) -> (Double) -> Double {
        switch effect {
        case .pop:
            // Upward pitch blip with a click of noise at the start.
            return { t in
                let phase = 2 * .pi * (420 * t + 1400 * t * t)
                let noise = t < 0.012 ? Double.random(in: -1...1) * 0.25 * (1 - t / 0.012) : 0
                return sin(phase) * exp(-t * 20) * 0.55 + noise
            }
        case .chime:
            return { t in
                (sin(2 * .pi * 1046.5 * t) + 0.6 * sin(2 * .pi * 1568 * t)) * exp(-t * 8) * 0.22
            }
        case .rise:
            // Rising sweep for combo milestones.
            return { t in
                let phase = 2 * .pi * (400 * t + 900 * t * t)
                let envelope = min(1, t * 30) * exp(-t * 4)
                return (sin(phase) + 0.3 * sin(phase * 2)) * envelope * 0.28
            }
        case .thud:
            return { t in
                let phase = 2 * .pi * (95 * t - 40 * t * t)
                return sin(phase) * exp(-t * 11) * 0.9
            }
        case .buzz:
            return { t in
                let square: Double = sin(2 * .pi * 150 * t) >= 0 ? 1 : -1
                return square * exp(-t * 14) * 0.16
            }
        case .warning:
            return { t in
                let gate: Double = t < 0.08 || (t > 0.12 && t < 0.2) ? 1 : 0
                return sin(2 * .pi * 740 * t) * gate * 0.18
            }
        case .levelUp:
            // Three-note arpeggio.
            return { t in
                let notes = [659.25, 830.61, 987.77]
                let index = min(Int(t / 0.12), notes.count - 1)
                let local = t - Double(index) * 0.12
                return sin(2 * .pi * notes[index] * t) * exp(-local * 10) * 0.25
            }
        }
    }

    private static func render(duration: Double, format: AVAudioFormat, sample: (Double) -> Double) -> AVAudioPCMBuffer? {
        let frames = AVAudioFrameCount(duration * sampleRate)
        guard let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frames),
              let channel = buffer.floatChannelData?[0]
        else { return nil }
        buffer.frameLength = frames
        for index in 0..<Int(frames) {
            let t = Double(index) / sampleRate
            // Short fade-out avoids clicks at the end of the buffer.
            let fade = min(1, (duration - t) / 0.01)
            channel[index] = Float(sample(t) * fade)
        }
        return buffer
    }
}
