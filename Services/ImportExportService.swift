import Foundation

enum ImportExportService {
    static func exportEntries(_ entries: [KnowledgeEntry]) -> String {
        var text = "# BrainDump Knowledge Export\n"
        text += "# Exported: \(ISO8601DateFormatter().string(from: Date()))\n"
        text += "# Entries: \(entries.count)\n\n"

        for entry in entries.sorted(by: { $0.title < $1.title }) {
            text += "--- Entry ---\n"
            text += "Title: \(entry.title)\n"
            if !entry.tags.isEmpty {
                text += "Tags: \(entry.tags.joined(separator: ", "))\n"
            }
            text += "Created: \(ISO8601DateFormatter().string(from: entry.createdAt))\n"
            text += "Updated: \(ISO8601DateFormatter().string(from: entry.updatedAt))\n"
            text += "Content:\n\(entry.content)\n"
            text += "--- End ---\n\n"
        }

        return text
    }

    static func importEntries(from text: String) -> [KnowledgeEntry] {
        // Try JSON first
        if text.trimmingCharacters(in: .whitespacesAndNewlines).hasPrefix("[") {
            if let data = text.data(using: .utf8),
               let entries = try? JSONDecoder.braindump.decode([KnowledgeEntry].self, from: data) {
                return entries
            }
        }

        // Parse text format
        var entries: [KnowledgeEntry] = []
        let blocks = text.components(separatedBy: "--- Entry ---")

        for block in blocks {
            let trimmed = block.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty, trimmed.contains("Title:") else { continue }

            let endMarker = "--- End ---"
            let content: String
            if let endRange = trimmed.range(of: endMarker) {
                content = String(trimmed[..<endRange.lowerBound])
            } else {
                content = trimmed
            }

            let lines = content.components(separatedBy: "\n")
            var title = ""
            var tags: [String] = []
            var bodyLines: [String] = []
            var inContent = false

            for line in lines {
                if line.hasPrefix("Title: ") {
                    title = String(line.dropFirst(7))
                } else if line.hasPrefix("Tags: ") {
                    tags = String(line.dropFirst(6)).components(separatedBy: ",").map { $0.trimmingCharacters(in: .whitespaces) }
                } else if line.hasPrefix("Content:") {
                    inContent = true
                    let remainder = String(line.dropFirst(8)).trimmingCharacters(in: .whitespaces)
                    if !remainder.isEmpty { bodyLines.append(remainder) }
                } else if inContent {
                    bodyLines.append(line)
                }
            }

            guard !title.isEmpty else { continue }

            let entryContent = bodyLines.joined(separator: "\n").trimmingCharacters(in: .whitespacesAndNewlines)
            entries.append(KnowledgeEntry(title: title, content: entryContent, tags: tags))
        }

        return entries
    }
}
