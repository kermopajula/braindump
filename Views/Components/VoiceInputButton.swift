import SwiftUI

struct VoiceInputButton: View {
    @ObservedObject var speechRecognizer: SpeechRecognizer
    let onResult: (String) -> Void

    var body: some View {
        Button {
            if speechRecognizer.isRecording {
                speechRecognizer.stopRecording()
                let transcript = speechRecognizer.transcript.trimmingCharacters(in: .whitespacesAndNewlines)
                if !transcript.isEmpty {
                    onResult(transcript)
                }
            } else {
                speechRecognizer.startRecording()
            }
        } label: {
            Image(systemName: speechRecognizer.isRecording ? "mic.fill" : "mic")
                .font(.title2)
                .foregroundColor(speechRecognizer.isRecording ? .red : .accentColor)
                .frame(width: 50, height: 50)
                .background(
                    Circle()
                        .fill(speechRecognizer.isRecording ? Color.red.opacity(0.15) : Color.accentColor.opacity(0.15))
                )
                .scaleEffect(speechRecognizer.isRecording ? 1.1 : 1.0)
                .animation(.easeInOut(duration: 0.6).repeatForever(autoreverses: true), value: speechRecognizer.isRecording)
        }
    }
}
