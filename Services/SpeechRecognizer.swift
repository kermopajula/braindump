import Foundation
import Speech
import AVFoundation

@MainActor
final class SpeechRecognizer: ObservableObject {
    @Published var transcript: String = ""
    @Published var isRecording: Bool = false
    @Published var errorMessage: String?
    @Published var isAuthorized: Bool = false

    private var audioEngine: AVAudioEngine?
    private var recognitionTask: SFSpeechRecognitionTask?
    private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?

    init() {
        checkAuthorization()
    }

    func checkAuthorization() {
        switch SFSpeechRecognizer.authorizationStatus() {
        case .authorized:
            isAuthorized = true
        case .notDetermined:
            requestAuthorization()
        default:
            isAuthorized = false
        }
    }

    private func requestAuthorization() {
        SFSpeechRecognizer.requestAuthorization { [weak self] status in
            Task { @MainActor in
                self?.isAuthorized = status == .authorized
            }
        }
    }

    func startRecording() {
        guard !isRecording else { return }

        if SFSpeechRecognizer.authorizationStatus() != .authorized {
            requestAuthorization()
            return
        }

        transcript = ""
        errorMessage = nil

        let recognizer = SFSpeechRecognizer()
        guard let recognizer, recognizer.isAvailable else {
            errorMessage = "Speech recognition is not available on this device."
            return
        }

        do {
            let audioSession = AVAudioSession.sharedInstance()
            try audioSession.setCategory(.record, mode: .measurement, options: .duckOthers)
            try audioSession.setActive(true, options: .notifyOthersOnDeactivation)

            let engine = AVAudioEngine()
            let request = SFSpeechAudioBufferRecognitionRequest()
            request.shouldReportPartialResults = true
            request.requiresOnDeviceRecognition = recognizer.supportsOnDeviceRecognition

            let inputNode = engine.inputNode
            let recordingFormat = inputNode.outputFormat(forBus: 0)
            inputNode.installTap(onBus: 0, bufferSize: 1024, format: recordingFormat) { buffer, _ in
                request.append(buffer)
            }

            engine.prepare()
            try engine.start()

            recognitionTask = recognizer.recognitionTask(with: request) { [weak self] result, error in
                Task { @MainActor in
                    if let result {
                        self?.transcript = result.bestTranscription.formattedString
                    }
                    if error != nil || (result?.isFinal ?? false) {
                        self?.stopRecording()
                    }
                }
            }

            audioEngine = engine
            recognitionRequest = request
            isRecording = true
        } catch {
            errorMessage = "Failed to start recording: \(error.localizedDescription)"
        }
    }

    func stopRecording() {
        audioEngine?.stop()
        audioEngine?.inputNode.removeTap(onBus: 0)
        recognitionRequest?.endAudio()
        recognitionTask?.cancel()

        audioEngine = nil
        recognitionRequest = nil
        recognitionTask = nil
        isRecording = false

        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
    }
}
