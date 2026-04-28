import SwiftUI

struct KnowledgeListView: View {
    @EnvironmentObject var store: KnowledgeStore
    @State private var searchText = ""
    @State private var selectedEntry: KnowledgeEntry?
    @State private var showEditSheet = false

    var filteredEntries: [KnowledgeEntry] {
        if searchText.isEmpty {
            return store.entries.sorted { $0.updatedAt > $1.updatedAt }
        }
        return store.search(query: searchText)
    }

    var body: some View {
        NavigationStack {
            Group {
                if store.entries.isEmpty {
                    ContentUnavailableView(
                        "No Knowledge Yet",
                        systemImage: "brain.head.profile",
                        description: Text("Add your first piece of knowledge using the Add tab.")
                    )
                } else {
                    List {
                        ForEach(filteredEntries) { entry in
                            Button {
                                selectedEntry = entry
                                showEditSheet = true
                            } label: {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(entry.title)
                                        .font(.headline)
                                        .foregroundColor(.primary)

                                    Text(entry.content)
                                        .font(.subheadline)
                                        .foregroundColor(.secondary)
                                        .lineLimit(2)

                                    if !entry.tags.isEmpty {
                                        HStack {
                                            ForEach(entry.tags, id: \.self) { tag in
                                                Text(tag)
                                                    .font(.caption2)
                                                    .padding(.horizontal, 6)
                                                    .padding(.vertical, 2)
                                                    .background(Color.accentColor.opacity(0.15))
                                                    .cornerRadius(4)
                                            }
                                        }
                                    }

                                    Text("Updated \(entry.updatedAt.formatted(.relative(presentation: .named)))")
                                        .font(.caption2)
                                        .foregroundStyle(.tertiary)
                                }
                                .padding(.vertical, 4)
                            }
                        }
                        .onDelete { indexSet in
                            let entriesToDelete = indexSet.map { filteredEntries[$0] }
                            for entry in entriesToDelete {
                                store.delete(id: entry.id)
                            }
                        }
                    }
                    .searchable(text: $searchText, prompt: "Search knowledge...")
                }
            }
            .navigationTitle("Knowledge")
            .sheet(isPresented: $showEditSheet) {
                if let entry = selectedEntry {
                    EditEntryView(entry: entry)
                }
            }
        }
    }
}

struct EditEntryView: View {
    @EnvironmentObject var store: KnowledgeStore
    @Environment(\.dismiss) var dismiss

    let entry: KnowledgeEntry
    @State private var title: String
    @State private var content: String
    @State private var tagsText: String

    init(entry: KnowledgeEntry) {
        self.entry = entry
        _title = State(initialValue: entry.title)
        _content = State(initialValue: entry.content)
        _tagsText = State(initialValue: entry.tags.joined(separator: ", "))
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Title") {
                    TextField("Title", text: $title)
                }

                Section("Content") {
                    TextEditor(text: $content)
                        .frame(minHeight: 100)
                }

                Section("Tags") {
                    TextField("Tags (comma separated)", text: $tagsText)
                }

                Section {
                    HStack {
                        Text("Created")
                        Spacer()
                        Text(entry.createdAt.formatted())
                            .foregroundColor(.secondary)
                    }
                    HStack {
                        Text("Updated")
                        Spacer()
                        Text(entry.updatedAt.formatted())
                            .foregroundColor(.secondary)
                    }
                }

                Section {
                    Button("Delete Entry", role: .destructive) {
                        store.delete(id: entry.id)
                        dismiss()
                    }
                }
            }
            .navigationTitle("Edit Entry")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        var updated = entry
                        updated.title = title
                        updated.content = content
                        updated.tags = tagsText.components(separatedBy: ",").map { $0.trimmingCharacters(in: .whitespaces) }.filter { !$0.isEmpty }
                        store.update(updated)
                        dismiss()
                    }
                }
            }
        }
    }
}
