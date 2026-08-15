import SwiftUI

struct AddKnowledgeView: View {
    @EnvironmentObject var store: KnowledgeStore
    @EnvironmentObject var settings: AppSettings
    @StateObject private var speechRecognizer = SpeechRecognizer()
    @FocusState private var isEditorFocused: Bool

    @State private var inputText: String = ""
    @State private var showConflictAlert = false
    @State private var conflictEntry: KnowledgeEntry?
    @State private var pendingTitle = ""
    @State private var pendingContent = ""
    @State private var pendingTags: [String] = []
    @State private var showSavedConfirmation = false
    @State private var isProcessing = false
    @State private var errorMessage: String?

    private let placeholder = """
        Type or speak what you want to remember…

        • My hip measurement is 92 cm
        • Basement keys are in the top drawer of the hallway shelf
        • To reboot the heating: hold reset 5 seconds, wait for green light
        """

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                editor
                statusRow
                actionBar
            }
            .background(Color(.systemGroupedBackground).ignoresSafeArea())
            .navigationTitle("Add")
            .toolbar {
                ToolbarItemGroup(placement: .keyboard) {
                    Spacer()
                    Button("Done") {
                        isEditorFocused = false
                    }
                }
            }
            .alert("Update Existing Entry?", isPresented: $showConflictAlert) {
                Button("Update Existing") {
                    if let existing = conflictEntry {
                        var updated = existing
                        updated.content = pendingContent
                        updated.tags = pendingTags
                        store.update(updated)
                        clearInput()
                    }
                }
                Button("Save as New", role: .cancel) {
                    let entry = KnowledgeEntry(title: pendingTitle, content: pendingContent, tags: pendingTags)
                    store.add(entry)
                    clearInput()
                }
            } message: {
                Text("An entry titled \"\(conflictEntry?.title ?? "")\" already exists. Would you like to update it or save as a new entry?")
            }
            .overlay {
                if showSavedConfirmation {
                    savedConfirmationOverlay
                }
            }
        }
    }

    // MARK: - Subviews

    private var editor: some View {
        ZStack(alignment: .topLeading) {
            TextEditor(text: $inputText)
                .focused($isEditorFocused)
                .scrollContentBackground(.hidden)
                .padding(12)
                .background(Color(.secondarySystemGroupedBackground))
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))

            if inputText.isEmpty {
                Text(placeholder)
                    .foregroundStyle(.tertiary)
                    .padding(.horizontal, 17)
                    .padding(.top, 20)
                    .allowsHitTesting(false)
            }
        }
        .padding(.horizontal)
        .padding(.top)
    }

    @ViewBuilder
    private var statusRow: some View {
        if let error = errorMessage {
            Label(error, systemImage: "exclamationmark.circle.fill")
                .font(.footnote)
                .foregroundStyle(.red)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal)
                .padding(.top, 8)
        } else if speechRecognizer.isRecording {
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
            .padding(.horizontal)
            .padding(.top, 8)
        } else if let voiceError = speechRecognizer.errorMessage {
            Label(voiceError, systemImage: "mic.slash.fill")
                .font(.footnote)
                .foregroundStyle(.red)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal)
                .padding(.top, 8)
        }
    }

    private var actionBar: some View {
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
                saveKnowledge()
            } label: {
                HStack(spacing: 6) {
                    if isProcessing {
                        ProgressView()
                            .controlSize(.small)
                            .tint(.white)
                    } else {
                        Image(systemName: "square.and.arrow.down")
                    }
                    Text(isProcessing ? "Processing…" : "Save")
                        .fontWeight(.semibold)
                }
                .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .disabled(cannotSave)
        }
        .padding()
    }

    private var savedConfirmationOverlay: some View {
        VStack(spacing: 12) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 48))
                .foregroundStyle(.green)
            Text("Saved")
                .font(.headline)
        }
        .padding(28)
        .background(.regularMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .transition(.scale.combined(with: .opacity))
    }

    // MARK: - Actions

    private var cannotSave: Bool {
        inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isProcessing
    }

    private func toggleVoice() {
        if speechRecognizer.isRecording {
            speechRecognizer.stopRecording()
            let transcript = speechRecognizer.transcript.trimmingCharacters(in: .whitespacesAndNewlines)
            if !transcript.isEmpty {
                if inputText.isEmpty {
                    inputText = transcript
                } else {
                    inputText += " " + transcript
                }
            }
        } else {
            isEditorFocused = false
            speechRecognizer.startRecording()
        }
    }

    private func saveKnowledge() {
        let text = inputText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }

        // Use AI to process the entry when a provider is ready (Apple Intelligence
        // needs no key; external providers need one).
        if settings.isAIReady {
            isProcessing = true
            errorMessage = nil
            Task {
                do {
                    let service = AIServiceFactory.create(provider: settings.selectedProvider, apiKey: settings.apiKey)
                    let processed = try await service.processNewEntry(rawText: text, existingEntries: store.entries)

                    await MainActor.run {
                        pendingTitle = processed.title
                        pendingContent = processed.content
                        pendingTags = processed.tags
                        isProcessing = false

                        if let matchID = processed.matchingEntryID,
                           let existing = store.entries.first(where: { $0.id == matchID }) {
                            conflictEntry = existing
                            showConflictAlert = true
                        } else {
                            let conflicts = store.findConflicts(title: processed.title)
                            if let existing = conflicts.first {
                                conflictEntry = existing
                                showConflictAlert = true
                            } else {
                                let entry = KnowledgeEntry(title: processed.title, content: processed.content, tags: processed.tags)
                                store.add(entry)
                                clearInput()
                            }
                        }
                    }
                } catch {
                    await MainActor.run {
                        isProcessing = false
                        // Fallback: save without AI processing
                        saveWithoutAI(text)
                    }
                }
            }
        } else {
            saveWithoutAI(text)
        }
    }

    private func saveWithoutAI(_ text: String) {
        // Simple heuristic: first line or first sentence as title
        let lines = text.components(separatedBy: "\n").filter { !$0.isEmpty }
        let title: String
        let content: String

        if lines.count > 1 {
            title = String(lines[0].prefix(100))
            content = text
        } else {
            // Use first sentence or first N chars as title
            let firstSentence = text.components(separatedBy: ". ").first ?? text
            title = String(firstSentence.prefix(100))
            content = text
        }

        let conflicts = store.findConflicts(title: title)
        if let existing = conflicts.first {
            pendingTitle = title
            pendingContent = content
            pendingTags = []
            conflictEntry = existing
            showConflictAlert = true
        } else {
            let entry = KnowledgeEntry(title: title, content: content)
            store.add(entry)
            clearInput()
        }
    }

    private func clearInput() {
        inputText = ""
        showSavedConfirmation = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            showSavedConfirmation = false
        }
    }
}
