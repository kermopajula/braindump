import SwiftUI
import UniformTypeIdentifiers

struct SettingsView: View {
    @EnvironmentObject var store: KnowledgeStore
    @EnvironmentObject var settings: AppSettings

    @State private var showExporter = false
    @State private var showImporter = false
    @State private var showPrivacy = false
    @State private var importResult: String?
    @State private var showTestResult = false
    @State private var testResultMessage = ""
    @State private var isTesting = false

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Picker("Provider", selection: $settings.selectedProvider) {
                        ForEach(AIProvider.allCases) { provider in
                            Text(provider.displayName).tag(provider)
                        }
                    }

                    if settings.selectedProvider.requiresAPIKey {
                        SecureField("API Key", text: $settings.apiKey)
                            .textContentType(.password)
                            .autocorrectionDisabled()
                            .textInputAutocapitalization(.never)

                        Button {
                            testConnection()
                        } label: {
                            HStack {
                                Text("Test Connection")
                                if isTesting {
                                    Spacer()
                                    ProgressView()
                                }
                            }
                        }
                        .disabled(!settings.isAIReady || isTesting)
                    }
                } header: {
                    Text("AI Provider")
                } footer: {
                    Text(providerFooter)
                        .font(.caption)
                }

                Section("Knowledge Base") {
                    HStack {
                        Text("Entries")
                        Spacer()
                        Text("\(store.entries.count)")
                            .foregroundColor(.secondary)
                    }

                    Button {
                        showExporter = true
                    } label: {
                        Label("Export Knowledge", systemImage: "square.and.arrow.up")
                    }
                    .disabled(store.entries.isEmpty)

                    Button {
                        showImporter = true
                    } label: {
                        Label("Import Knowledge", systemImage: "square.and.arrow.down")
                    }

                    if let result = importResult {
                        Text(result)
                            .font(.caption)
                            .foregroundColor(.green)
                    }
                }

                Section("Privacy") {
                    Button {
                        showPrivacy = true
                    } label: {
                        Label("Privacy Information", systemImage: "lock.shield")
                    }
                }

                Section("About") {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("BrainDump")
                            .font(.headline)
                        Text("Personal Knowledge Vault")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }

                    HStack {
                        Text("Version")
                        Spacer()
                        Text("1.0.0")
                            .foregroundColor(.secondary)
                    }

                    Text("Capture anything you want to remember—measurements, locations, instructions, notes. Ask questions and get answers from your own knowledge. All data stays on your device.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            .navigationTitle("Settings")
            .alert("Connection Test", isPresented: $showTestResult) {
                Button("OK") {}
            } message: {
                Text(testResultMessage)
            }
            .sheet(isPresented: $showPrivacy) {
                PrivacyNoticeView()
            }
            .fileExporter(
                isPresented: $showExporter,
                document: KnowledgeDocument(text: store.exportAsText()),
                contentType: .plainText,
                defaultFilename: "braindump-export.txt"
            ) { _ in }
            .fileImporter(
                isPresented: $showImporter,
                allowedContentTypes: [.plainText, .json],
                allowsMultipleSelection: false
            ) { result in
                handleImport(result)
            }
        }
    }

    private var providerFooter: String {
        switch settings.selectedProvider {
        case .appleFoundation:
            if #available(iOS 26.0, *) {
                if let issue = FoundationModelsClient.availabilityMessage {
                    return "\(issue) Pick OpenAI or Anthropic and add an API key for cloud AI."
                }
                return "Runs on your device using Apple Intelligence — free, private, no API key. If you want a more capable model for complex questions, switch to OpenAI or Anthropic and add your own API key."
            } else {
                return "Apple Intelligence requires iOS 26 or later. Pick OpenAI or Anthropic and add an API key."
            }
        case .openAI, .anthropic:
            return "Your key is stored only on this device and used to call \(settings.selectedProvider.displayName) directly. You're billed by the provider for usage."
        }
    }

    private func testConnection() {
        isTesting = true
        Task {
            do {
                let service = AIServiceFactory.create(provider: settings.selectedProvider, apiKey: settings.apiKey)
                let testEntries = [KnowledgeEntry(title: "Test", content: "This is a test entry.")]
                let response = try await service.ask(question: "What is the test entry about?", context: testEntries)
                await MainActor.run {
                    testResultMessage = "Connection successful!\n\nResponse: \(response.answer)"
                    showTestResult = true
                    isTesting = false
                }
            } catch {
                await MainActor.run {
                    testResultMessage = "Connection failed: \(error.localizedDescription)"
                    showTestResult = true
                    isTesting = false
                }
            }
        }
    }

    private func handleImport(_ result: Result<[URL], Error>) {
        switch result {
        case .success(let urls):
            guard let url = urls.first else { return }
            guard url.startAccessingSecurityScopedResource() else { return }
            defer { url.stopAccessingSecurityScopedResource() }

            if let text = try? String(contentsOf: url) {
                let count = store.importFromText(text)
                importResult = "Imported \(count) entries"
                DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
                    importResult = nil
                }
            }
        case .failure(let error):
            importResult = "Import failed: \(error.localizedDescription)"
        }
    }
}

struct KnowledgeDocument: FileDocument {
    static var readableContentTypes: [UTType] { [.plainText] }

    var text: String

    init(text: String) {
        self.text = text
    }

    init(configuration: ReadConfiguration) throws {
        if let data = configuration.file.regularFileContents {
            text = String(data: data, encoding: .utf8) ?? ""
        } else {
            text = ""
        }
    }

    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        FileWrapper(regularFileWithContents: Data(text.utf8))
    }
}
