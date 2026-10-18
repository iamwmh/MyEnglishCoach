import Foundation
import Speech
import AVFoundation

enum SpeechError: LocalizedError {
    case microphoneDenied
    case speechDenied
    case unavailable
    case empty

    var errorDescription: String? {
        switch self {
        case .microphoneDenied: "请在系统设置中允许麦克风，才能录制口语。"
        case .speechDenied: "请允许语音识别，才能把录音转成文字并评分。"
        case .unavailable: "当前无法使用英语语音识别。"
        case .empty: "没有识别到英语内容，请靠近麦克风再读一遍。"
        }
    }
}

@Observable
final class SpeechPracticeController {
    var isRecording = false
    var lastTranscript = ""
    var errorMessage: String?

    private var recorder: AVAudioRecorder?
    private var fileURL: URL?
    private var recognitionTask: SFSpeechRecognitionTask?

    func start() async throws {
        errorMessage = nil
        lastTranscript = ""
        try await ensurePermission()
        stopAudioSessionIfNeeded()

        let session = AVAudioSession.sharedInstance()
                try session.setCategory(.playAndRecord, mode: .spokenAudio, options: [.defaultToSpeaker, .allowBluetoothHFP])
        try session.setActive(true)

        let url = FileManager.default.temporaryDirectory.appendingPathComponent("recitation-\(UUID().uuidString).m4a")
        fileURL = url
        let settings: [String: Any] = [
            AVFormatIDKey: Int(kAudioFormatMPEG4AAC),
            AVSampleRateKey: 44100,
            AVNumberOfChannelsKey: 1,
            AVEncoderAudioQualityKey: AVAudioQuality.high.rawValue
        ]
        let recorder = try AVAudioRecorder(url: url, settings: settings)
        recorder.prepareToRecord()
        recorder.record()
        self.recorder = recorder
        isRecording = true
    }

    func stopAndTranscribe() async throws -> String {
        recorder?.stop()
        recorder = nil
        isRecording = false
        guard let fileURL else { throw SpeechError.empty }
        let text = try await transcribe(url: fileURL)
        lastTranscript = text
        if text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            throw SpeechError.empty
        }
        return text
    }

    func cancel() {
        recorder?.stop()
        recorder = nil
        recognitionTask?.cancel()
        recognitionTask = nil
        isRecording = false
    }

    private func ensurePermission() async throws {
        let speechStatus = await withCheckedContinuation { continuation in
            SFSpeechRecognizer.requestAuthorization { status in
                continuation.resume(returning: status)
            }
        }
        guard speechStatus == .authorized else { throw SpeechError.speechDenied }

        let granted = await AVAudioApplication.requestRecordPermission()
        guard granted else { throw SpeechError.microphoneDenied }
    }

    private func transcribe(url: URL) async throws -> String {
        guard let recognizer = SFSpeechRecognizer(locale: Locale(identifier: "en-US")), recognizer.isAvailable else {
            throw SpeechError.unavailable
        }
        let request = SFSpeechURLRecognitionRequest(url: url)
        request.shouldReportPartialResults = false
        request.addsPunctuation = false

        return try await withCheckedThrowingContinuation { continuation in
            var finished = false
            recognitionTask = recognizer.recognitionTask(with: request) { result, error in
                if finished { return }
                if let error {
                    finished = true
                    continuation.resume(throwing: error)
                    return
                }
                guard let result, result.isFinal else { return }
                finished = true
                continuation.resume(returning: result.bestTranscription.formattedString)
            }
        }
    }

    private func stopAudioSessionIfNeeded() {
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
    }
}
