import Foundation

final class KnowledgeStore: ObservableObject {
    @Published private(set) var entries: [KnowledgeEntry] = []

    private let fileURL: URL

    init() {
        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        self.fileURL = docs.appendingPathComponent("knowledge.json")
        load()
    }

    // MARK: - CRUD

    func add(_ entry: KnowledgeEntry) {
        entries.append(entry)
        save()
    }

    func update(_ entry: KnowledgeEntry) {
        guard let index = entries.firstIndex(where: { $0.id == entry.id }) else { return }
        var updated = entry
        updated.updatedAt = Date()
        entries[index] = updated
        save()
    }

    func delete(id: UUID) {
        entries.removeAll { $0.id == id }
        save()
    }

    func replaceEntry(id: UUID, with newEntry: KnowledgeEntry) {
        guard let index = entries.firstIndex(where: { $0.id == id }) else { return }
        var updated = newEntry
        updated.updatedAt = Date()
        entries[index] = updated
        save()
    }

    // MARK: - Search

    func search(query: String) -> [KnowledgeEntry] {
        let q = query.lowercased()
        let words = q.split(separator: " ").map(String.init)
        if words.isEmpty { return entries }

        return entries
            .map { entry -> (KnowledgeEntry, Int) in
                let text = "\(entry.title) \(entry.content) \(entry.tags.joined(separator: " "))".lowercased()
                let score = words.reduce(0) { $0 + (text.contains($1) ? 1 : 0) }
                return (entry, score)
            }
            .filter { $0.1 > 0 }
            .sorted { $0.1 > $1.1 }
            .map(\.0)
    }

    func findConflicts(title: String) -> [KnowledgeEntry] {
        let normalized = title.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
        return entries.filter { $0.title.lowercased().trimmingCharacters(in: .whitespacesAndNewlines) == normalized }
    }

    // MARK: - Import / Export

    func exportAsText() -> String {
        ImportExportService.exportEntries(entries)
    }

    func importFromText(_ text: String) -> Int {
        let imported = ImportExportService.importEntries(from: text)
        var count = 0
        for entry in imported {
            let conflicts = findConflicts(title: entry.title)
            if let existing = conflicts.first {
                var merged = existing
                merged.content = entry.content
                merged.tags = entry.tags
                update(merged)
            } else {
                add(entry)
            }
            count += 1
        }
        return count
    }

    func replaceAll(with entries: [KnowledgeEntry]) {
        self.entries = entries
        save()
    }

    // MARK: - Persistence

    private func load() {
        guard FileManager.default.fileExists(atPath: fileURL.path) else { return }
        do {
            let data = try Data(contentsOf: fileURL)
            entries = try JSONDecoder.braindump.decode([KnowledgeEntry].self, from: data)
        } catch {
            print("Failed to load knowledge base: \(error)")
        }
    }

    private func save() {
        do {
            let data = try JSONEncoder.braindump.encode(entries)
            try data.write(to: fileURL, options: .atomic)
        } catch {
            print("Failed to save knowledge base: \(error)")
        }
    }
}

extension JSONEncoder {
    static let braindump: JSONEncoder = {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        return encoder
    }()
}

extension JSONDecoder {
    static let braindump: JSONDecoder = {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }()
}
