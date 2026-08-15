import SwiftUI

struct AskView: View {
    @EnvironmentObject var store: KnowledgeStore
    @EnvironmentObject var settings: AppSettings
    @StateObject private var speechRecognizer = SpeechRecognizer()
    @FocusState private var isQuestionFocused: Bool

    @State private var question: String = ""
    @State private var answer: String = ""
    @State private var suggestedUpdates: [KnowledgeUpdate] = []
    @State private var isLoading = false
    @State private var errorMessage: String?

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    inputCard

                    if !settings.isAIReady {
                        infoBanner(
                            icon: "exclamationmark.triangle.fill",
                            text: "Add your API key in Settings to use the Ask feature.",
                            tint: .orange
                        )
                    }

                    if store.entries.isEmpty {
                        infoBanner(
                            icon: "info.circle.fill",
                            text: "Add some knowledge first so there's something to search.",
                            tint: .secondary
                        )
                    }

                    if let error = errorMessage {
                        errorRow(error)
                    }

                    if !answer.isEmpty {
                        answerCard
                    }

                    if !suggestedUpdates.isEmpty {
                        suggestedSection
                    }
                }
                .padding(.horizontal)
                .padding(.top)
                .padding(.bottom, 24)
            }
            .background(Color(.systemGroupedBackground).ignoresSafeArea())
            .scrollDismissesKeyboard(.interactively)
            .navigationTitle("Ask")
        }
    }

    // MARK: - Subviews

    private var inputCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            TextField(
                "Ask about your knowledge…",
                text: $question,
                axis: .vertical
            )
            .focused($isQuestionFocused)
            .lineLimit(1...5)
            .submitLabel(.send)
            .onSubmit { askQuestion() }
            .padding(12)
            .background(Color(.secondarySystemGroupedBackground))
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))

            HStack(spacing: 12) {
                Button {
                    toggleVoice()
                } label: {
                    Image(systemName: speechRecognizer.isRecording ? "stop.fill" : "mic.fill")
                        .font(.body.weight(.semibold))
                        .frame(width: 44)
                }
                .buttonStyle(.bordered)
                .controlSize(.large)
                .tint(speechRecognizer.isRecording ? .red : .accentColor)
                .accessibilityLabel(speechRecognizer.isRecording ? "Stop recording" : "Start voice input")

                Button {
                    askQuestion()
                } label: {
                    HStack(spacing: 6) {
                        if isLoading {
                            ProgressView()
                                .controlSize(.small)
                                .tint(.white)
                        } else {
                            Image(systemName: "paperplane.fill")
                        }
                        Text(isLoading ? "Thinking…" : "Ask")
                            .fontWeight(.semibold)
                    }
                    .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .disabled(!canAsk)
            }

            if speechRecognizer.isRecording {
                HStack(spacing: 6) {
                    Image(systemName: "waveform")
                        .foregroundStyle(.red)
                        .symbolEffect(.variableColor.iterative, isActive: true)
                    Text(speechRecognizer.transcript.isEmpty ? "Listening…" : speechRecognizer.transcript)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                    Spacer()
                }
            }
        }
    }

    private var answerCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("Answer", systemImage: "brain.head.profile")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.secondary)
            Text(answer)
                .font(.body)
                .frame(maxWidth: .infinity, alignment: .leading)
                .textSelection(.enabled)
        }
        .padding()
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
    }

    private var suggestedSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("Suggested Updates", systemImage: "arrow.triangle.2.circlepath")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.secondary)
            ForEach(suggestedUpdates) { update in
                SuggestedUpdateCard(update: update) {
                    applyUpdate(update)
                }
            }
        }
    }

    private func errorRow(_ text: String) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundStyle(.red)
            Text(text)
                .font(.footnote)
                .foregroundStyle(.primary)
            Spacer()
        }
        .padding()
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }

    private func infoBanner(icon: String, text: String, tint: Color) -> some View {
        HStack(spacing: 10) {
            Image(systemName: icon)
                .foregroundStyle(tint)
            Text(text)
                .font(.footnote)
                .foregroundStyle(.secondary)
            Spacer()
        }
        .padding()
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }

    // MARK: - Actions

    private var canAsk: Bool {
        !question.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        && settings.isAIReady
        && !isLoading
    }

    private func toggleVoice() {
        if speechRecognizer.isRecording {
            speechRecognizer.stopRecording()
            let transcript = speechRecognizer.transcript.trimmingCharacters(in: .whitespacesAndNewlines)
            if !transcript.isEmpty {
                question = transcript
                askQuestion()
            }
        } else {
            isQuestionFocused = false
            speechRecognizer.startRecording()
        }
    }

    private func askQuestion() {
        let q = question.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !q.isEmpty, settings.isAIReady else { return }

        isQuestionFocused = false
        isLoading = true
        errorMessage = nil
        answer = ""
        suggestedUpdates = []

        Task {
            do {
                let service = AIServiceFactory.create(provider: settings.selectedProvider, apiKey: settings.apiKey)

                // Use relevant entries (search-based) to stay within context limits
                let context: [KnowledgeEntry]
                if store.entries.count <= 50 {
                    context = store.entries
                } else {
                    let results = store.search(query: q)
                    context = Array(results.prefix(50))
                }

                let response = try await service.ask(question: q, context: context)

                await MainActor.run {
                    answer = response.answer
                    suggestedUpdates = response.suggestedUpdates
                    isLoading = false
                }
            } catch {
                await MainActor.run {
                    errorMessage = error.localizedDescription
                    isLoading = false
                }
            }
        }
    }

    private func applyUpdate(_ update: KnowledgeUpdate) {
        if let existingID = update.existingEntryID,
           var existing = store.entries.first(where: { $0.id == existingID }) {
            existing.content = update.content
            existing.tags = update.tags
            store.update(existing)
        } else {
            let entry = KnowledgeEntry(title: update.title, content: update.content, tags: update.tags)
            store.add(entry)
        }
        suggestedUpdates.removeAll { $0.id == update.id }
    }
}

struct SuggestedUpdateCard: View {
    let update: KnowledgeUpdate
    let onApply: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(update.title)
                .font(.subheadline.weight(.semibold))

            Text(update.content)
                .font(.footnote)
                .foregroundStyle(.secondary)
                .lineLimit(3)

            if !update.reason.isEmpty {
                Text(update.reason)
                    .font(.caption)
                    .foregroundStyle(.orange)
            }

            Button {
                onApply()
            } label: {
                Label("Apply", systemImage: "checkmark.circle.fill")
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.small)
            .padding(.top, 4)
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }
}
