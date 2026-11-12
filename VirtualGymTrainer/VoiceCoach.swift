import AVFoundation

/// Speaks rep counts and form corrections during a workout.
final class VoiceCoach {
    var isMuted = false {
        didSet {
            if isMuted { synthesizer.stopSpeaking(at: .immediate) }
        }
    }

    private let synthesizer = AVSpeechSynthesizer()

    // A correction is spoken only after the problem has lasted this long...
    private let minimumProblemDuration: TimeInterval = 1.0
    // ...and the same correction is not repeated more often than this...
    private let repeatInterval: TimeInterval = 8.0
    // ...with at least this much quiet between any two corrections.
    private let minimumGap: TimeInterval = 3.0

    private var firstSeen: [String: Date] = [:]
    private var lastSpoken: [String: Date] = [:]
    private var lastCorrectionTime = Date.distantPast

    /// Call when the training screen appears.
    func start() {
        // Play through the speaker even when the phone's silent switch is on,
        // and lower any music that is playing while the coach talks.
        let session = AVAudioSession.sharedInstance()
        do {
            try session.setCategory(.playback, mode: .voicePrompt, options: [.duckOthers])
            try session.setActive(true)
        } catch {
            print("❌ Audio session error: \(error.localizedDescription)")
        }
    }

    /// Call when the training screen goes away.
    func stop() {
        synthesizer.stopSpeaking(at: .immediate)
        firstSeen.removeAll()
        lastSpoken.removeAll()
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
    }

    /// Says the rep number. Rep counts take priority over corrections.
    func announceRep(_ count: Int) {
        speak("\(count)", interrupting: true)
    }

    /// Says a one-off correction right away (for example after a shallow rep).
    func announceNow(_ cue: String) {
        let now = Date()
        guard now.timeIntervalSince(lastCorrectionTime) >= minimumGap else { return }
        lastCorrectionTime = now
        lastSpoken[cue] = now
        speak(cue, interrupting: false)
    }

    /// Call on every analyzed frame with the corrections that currently apply.
    /// Speaks one only when its problem has persisted, and never nags.
    func update(cues: [String]) {
        let now = Date()

        // Forget problems that have gone away.
        firstSeen = firstSeen.filter { cues.contains($0.key) }
        for cue in cues where firstSeen[cue] == nil {
            firstSeen[cue] = now
        }

        guard !synthesizer.isSpeaking,
              now.timeIntervalSince(lastCorrectionTime) >= minimumGap else { return }

        for cue in cues {
            guard let seen = firstSeen[cue],
                  now.timeIntervalSince(seen) >= minimumProblemDuration,
                  now.timeIntervalSince(lastSpoken[cue] ?? .distantPast) >= repeatInterval else { continue }
            lastSpoken[cue] = now
            lastCorrectionTime = now
            speak(cue, interrupting: false)
            break
        }
    }

    private func speak(_ text: String, interrupting: Bool) {
        guard !isMuted else { return }
        if interrupting {
            synthesizer.stopSpeaking(at: .immediate)
        }
        let utterance = AVSpeechUtterance(string: text)
        utterance.voice = AVSpeechSynthesisVoice(language: "en-US")
        synthesizer.speak(utterance)
    }
}
