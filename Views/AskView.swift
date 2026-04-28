import SwiftUI

struct AskView: View {
    @EnvironmentObject var store: KnowledgeStore
    @EnvironmentObject var settings: AppSettings
    @StateObject private var speechRecognizer = SpeechRecognizer()

    @State private var question: String = ""
    @State private var answer: String = ""
    @State private var suggestedUpdates: [KnowledgeUpdate] = []
    @State private var isLoading = false
    @State private var errorMessage: String?

    var body: some View {
        NavigationStack {
            VStack(spacing: 16) {
                // Question input
                HStack(spacing: 12) {
                    TextField("Ask about your knowledge...", text: $question, axis: .vertical)
                        .textFieldStyle(.roundedBorder)
                        .lineLimit(1...4)
                        .onSubmit { askQuestion() }

                    VoiceInputButton(speechRecognizer: speechRecognizer) { transcript in
                        question = transcript
                        askQuestion()
                    }
                }
                .padding(.horizontal)

                // Ask button
                Button {
                    askQuestion()
                } label: {
                    Label("Ask", systemImage: "paperplane.fill")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(canAsk ? Color.accentColor : Color.gray)
                        .foregroundColor(.white)
                        .cornerRadius(12)
                }
                .disabled(!canAsk)
                .padding(.horizontal)

                if settings.apiKey.isEmpty {
                    HStack {
                        Image(systemName: "exclamationmark.triangle")
                        Text("Add your API key in Settings to use the Ask feature.")
                    }
                    .font(.caption)
                    .foregroundColor(.orange)
                    .padding(.horizontal)
                }

                if store.entries.isEmpty {
                    HStack {
                        Image(systemName: "info.circle")
                        Text("Add some knowledge first so there's something to search.")
                    }
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .padding(.horizontal)
                }

                // Results
                ScrollView {
                    VStack(alignment: .leading, spacing: 16) {
                        if isLoading {
                            HStack {
                                ProgressView()
                                Text("Thinking...")
                            }
                            .frame(maxWidth: .infinity)
                            .padding()
                        }

                        if let error = errorMessage {
                            Text(error)
                                .foregroundColor(.red)
                                .padding()
                                .background(Color(.systemGray6))
                                .cornerRadius(12)
                        }

                        if !answer.isEmpty {
                            VStack(alignment: .leading, spacing: 8) {
                                Label("Answer", systemImage: "brain.head.profile")
                                    .font(.headline)

                                Text(answer)
                                    .padding()
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .background(Color(.systemGray6))
                                    .cornerRadius(12)
                            }
                        }

                        if !suggestedUpdates.isEmpty {
                            VStack(alignment: .leading, spacing: 8) {
                                Label("Suggested Updates", systemImage: "arrow.triangle.2.circlepath")
                                    .font(.headline)

                                ForEach(suggestedUpdates) { update in
                                    SuggestedUpdateCard(update: update) {
                                        applyUpdate(update)
                                    }
                                }
                            }
                        }
                    }
                    .padding(.horizontal)
                }

                Spacer()
            }
            .padding(.top)
            .navigationTitle("Ask")
        }
    }

    private var canAsk: Bool {
        !question.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        && !settings.apiKey.isEmpty
        && !isLoading
    }

    private func askQuestion() {
        let q = question.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !q.isEmpty, !settings.apiKey.isEmpty else { return }

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
                .font(.subheadline.bold())

            Text(update.content)
                .font(.caption)
                .foregroundColor(.secondary)
                .lineLimit(3)

            if !update.reason.isEmpty {
                Text("Reason: \(update.reason)")
                    .font(.caption2)
                    .foregroundColor(.orange)
            }

            HStack {
                Button("Apply", action: onApply)
                    .buttonStyle(.borderedProminent)
                    .controlSize(.small)
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
}
