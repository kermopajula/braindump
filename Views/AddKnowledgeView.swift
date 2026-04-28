import SwiftUI

struct AddKnowledgeView: View {
    @EnvironmentObject var store: KnowledgeStore
    @EnvironmentObject var settings: AppSettings
    @StateObject private var speechRecognizer = SpeechRecognizer()

    @State private var inputText: String = ""
    @State private var showConflictAlert = false
    @State private var conflictEntry: KnowledgeEntry?
    @State private var pendingTitle = ""
    @State private var pendingContent = ""
    @State private var pendingTags: [String] = []
    @State private var showSavedConfirmation = false
    @State private var isProcessing = false
    @State private var errorMessage: String?

    var body: some View {
        NavigationStack {
            VStack(spacing: 16) {
                // Input area
                VStack(alignment: .leading, spacing: 8) {
                    Text("What do you want to remember?")
                        .font(.headline)

                    TextEditor(text: $inputText)
                        .frame(minHeight: 120)
                        .padding(8)
                        .background(Color(.systemGray6))
                        .cornerRadius(12)
                        .overlay(
                            Group {
                                if inputText.isEmpty {
                                    Text("Type or use voice to add knowledge...\n\nExamples:\n• My hip measurement is 92cm\n• Basement keys are in the top drawer of the hallway shelf\n• To reboot the heating: hold reset 5 seconds, wait for green light")
                                        .foregroundColor(.secondary)
                                        .padding(12)
                                        .allowsHitTesting(false)
                                }
                            },
                            alignment: .topLeading
                        )

                    if speechRecognizer.isRecording {
                        Text(speechRecognizer.transcript)
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .padding(.horizontal, 4)
                    }

                    if let error = speechRecognizer.errorMessage {
                        Text(error)
                            .font(.caption)
                            .foregroundColor(.red)
                    }
                }
                .padding(.horizontal)

                // Voice and Save buttons
                HStack(spacing: 20) {
                    VoiceInputButton(speechRecognizer: speechRecognizer) { transcript in
                        if inputText.isEmpty {
                            inputText = transcript
                        } else {
                            inputText += " " + transcript
                        }
                    }

                    Button {
                        saveKnowledge()
                    } label: {
                        Label("Save", systemImage: "square.and.arrow.down")
                            .font(.headline)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? Color.gray : Color.accentColor)
                            .foregroundColor(.white)
                            .cornerRadius(12)
                    }
                    .disabled(inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isProcessing)
                }
                .padding(.horizontal)

                if isProcessing {
                    ProgressView("Processing...")
                }

                if let error = errorMessage {
                    Text(error)
                        .font(.caption)
                        .foregroundColor(.red)
                        .padding(.horizontal)
                }

                Spacer()
            }
            .padding(.top)
            .navigationTitle("Add Knowledge")
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

    private func saveKnowledge() {
        let text = inputText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }

        // If API key available, use AI to process the entry
        if !settings.apiKey.isEmpty {
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

    private var savedConfirmationOverlay: some View {
        VStack {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 50))
                .foregroundColor(.green)
            Text("Saved!")
                .font(.headline)
        }
        .padding(30)
        .background(.ultraThinMaterial)
        .cornerRadius(20)
        .transition(.scale.combined(with: .opacity))
    }
}
