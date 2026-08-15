import Foundation

struct AIResponse {
    let answer: String
    let suggestedUpdates: [KnowledgeUpdate]
}

struct KnowledgeUpdate: Identifiable {
    let id = UUID()
    let existingEntryID: UUID?
    let title: String
    let content: String
    let tags: [String]
    let reason: String
}

protocol AIService {
    func ask(question: String, context: [KnowledgeEntry]) async throws -> AIResponse
    func processNewEntry(rawText: String, existingEntries: [KnowledgeEntry]) async throws -> ProcessedEntry
}

struct ProcessedEntry {
    let title: String
    let content: String
    let tags: [String]
    let matchingEntryID: UUID?
}

enum AIError: LocalizedError {
    case generationFailed(Error)
    case foundationModelsUnavailable(String)
    case unsupportedOS

    var errorDescription: String? {
        switch self {
        case .generationFailed(let error):
            return "The on-device model couldn't answer: \(error.localizedDescription)"
        case .foundationModelsUnavailable(let message):
            return message
        case .unsupportedOS:
            return "Apple Intelligence requires iOS 26 or later."
        }
    }
}

enum AIServiceFactory {
    static func create() -> AIService {
        if #available(iOS 26.0, macOS 26.0, *) {
            return FoundationModelsClient()
        }
        return UnsupportedOSClient()
    }
}

/// Stand-in used on an OS that's too old to support Apple Intelligence.
private struct UnsupportedOSClient: AIService {
    func ask(question: String, context: [KnowledgeEntry]) async throws -> AIResponse {
        throw AIError.unsupportedOS
    }
    func processNewEntry(rawText: String, existingEntries: [KnowledgeEntry]) async throws -> ProcessedEntry {
        throw AIError.unsupportedOS
    }
}

// MARK: - Prompts

enum AIPrompts {
    static let systemPrompt = """
    You are a personal knowledge base assistant. The user stores facts, measurements, instructions, \
    locations of items, and other personal information in their knowledge base.

    When answering questions:
    - Use ONLY the provided knowledge base entries to answer
    - Be concise and direct
    - If you don't have enough information, say so clearly
    - If you detect that the user's question contains NEW information that conflicts with or updates \
    an existing entry, include a suggested update
    """

    static func buildUserMessage(question: String, entries: [KnowledgeEntry]) -> String {
        var msg = "Knowledge Base:\n\n"
        for (i, entry) in entries.enumerated() {
            msg += "[\(i + 1)] ID: \(entry.id.uuidString)\n"
            msg += "Title: \(entry.title)\n"
            msg += "Content: \(entry.content)\n"
            if !entry.tags.isEmpty {
                msg += "Tags: \(entry.tags.joined(separator: ", "))\n"
            }
            msg += "Last Updated: \(ISO8601DateFormatter().string(from: entry.updatedAt))\n\n"
        }
        msg += "---\n\nQuestion: \(question)"
        return msg
    }

    static let processEntrySystemPrompt = """
    You help organize personal knowledge. Given raw text input, extract a structured knowledge entry.

    Rules for matchingEntryTitle:
    - Set it ONLY when the new input is about the exact same specific subject as an existing entry \
    (e.g. updating the location of the SAME item, correcting the SAME measurement, revising the SAME instructions).
    - A shared category or structural pattern is NOT a match. "Key is in the drawer" and "Charger is in the kitchen" \
    are both item locations but are about different items — leave it empty.
    - When in doubt, leave it empty. It is far better to create a new entry than to overwrite an unrelated one.
    """

    static func buildProcessEntryMessage(rawText: String, existingEntries: [KnowledgeEntry]) -> String {
        var msg = "Existing entries:\n"
        for entry in existingEntries {
            msg += "- \(entry.title)\n"
        }
        msg += "\nNew input: \(rawText)"
        return msg
    }
}
