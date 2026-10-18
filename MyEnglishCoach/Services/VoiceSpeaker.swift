import AVFoundation

@Observable
final class VoiceSpeaker {
    private let synthesizer = AVSpeechSynthesizer()

    var isSpeaking: Bool { synthesizer.isSpeaking }

    func speak(_ text: String, language: String = "en-US") {
        stop()
        let session = AVAudioSession.sharedInstance()
        try? session.setCategory(.playback, mode: .spokenAudio, options: [.duckOthers])
        try? session.setActive(true)

        let utterance = AVSpeechUtterance(string: text)
        utterance.voice = AVSpeechSynthesisVoice(language: language)
        utterance.rate = 0.43
        utterance.pitchMultiplier = 1.0
        synthesizer.speak(utterance)
    }

    func stop() {
        if synthesizer.isSpeaking {
            synthesizer.stopSpeaking(at: .immediate)
        }
    }
}
