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
    case noAPIKey
    case invalidResponse(Int)
    case decodingError(String)
    case networkError(Error)

    var errorDescription: String? {
        switch self {
        case .noAPIKey:
            return "No API key configured. Please add your API key in Settings."
        case .invalidResponse(let code):
            return "API returned status \(code). Please check your API key."
        case .decodingError(let msg):
            return "Failed to parse AI response: \(msg)"
        case .networkError(let error):
            return "Network error: \(error.localizedDescription)"
        }
    }
}

enum AIServiceFactory {
    static func create(provider: AIProvider, apiKey: String) -> AIService {
        switch provider {
        case .openAI:
            return OpenAIClient(apiKey: apiKey)
        case .anthropic:
            return AnthropicClient(apiKey: apiKey)
        }
    }
}

// MARK: - Shared Prompt

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

    Respond in JSON format:
    {
      "answer": "Your concise answer here",
      "suggestedUpdates": [
        {
          "existingEntryID": "uuid-string-or-null",
          "title": "Entry title",
          "content": "Updated content",
          "tags": ["tag1", "tag2"],
          "reason": "Why this update is needed"
        }
      ]
    }

    If there are no updates needed, return an empty suggestedUpdates array.
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

    Respond in JSON format:
    {
      "title": "A short descriptive title",
      "content": "The cleaned-up information",
      "tags": ["relevant", "tags"],
      "matchingEntryTitle": "title of existing entry this updates, or null"
    }
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

// MARK: - Response Parsing

enum AIResponseParser {
    static func parse(_ text: String, entries: [KnowledgeEntry]) -> AIResponse {
        // Try to extract JSON from the response
        let jsonString: String
        if let start = text.firstIndex(of: "{"),
           let end = text.lastIndex(of: "}") {
            jsonString = String(text[start...end])
        } else {
            return AIResponse(answer: text, suggestedUpdates: [])
        }

        guard let data = jsonString.data(using: .utf8) else {
            return AIResponse(answer: text, suggestedUpdates: [])
        }

        struct RawResponse: Decodable {
            let answer: String
            let suggestedUpdates: [RawUpdate]?

            struct RawUpdate: Decodable {
                let existingEntryID: String?
                let title: String
                let content: String
                let tags: [String]?
                let reason: String?
            }
        }

        do {
            let raw = try JSONDecoder().decode(RawResponse.self, from: data)
            let updates = (raw.suggestedUpdates ?? []).map { update in
                KnowledgeUpdate(
                    existingEntryID: update.existingEntryID.flatMap(UUID.init),
                    title: update.title,
                    content: update.content,
                    tags: update.tags ?? [],
                    reason: update.reason ?? ""
                )
            }
            return AIResponse(answer: raw.answer, suggestedUpdates: updates)
        } catch {
            return AIResponse(answer: text, suggestedUpdates: [])
        }
    }

    static func parseProcessedEntry(_ text: String, existingEntries: [KnowledgeEntry]) -> ProcessedEntry? {
        let jsonString: String
        if let start = text.firstIndex(of: "{"),
           let end = text.lastIndex(of: "}") {
            jsonString = String(text[start...end])
        } else {
            return nil
        }

        guard let data = jsonString.data(using: .utf8) else { return nil }

        struct RawEntry: Decodable {
            let title: String
            let content: String
            let tags: [String]?
            let matchingEntryTitle: String?
        }

        guard let raw = try? JSONDecoder().decode(RawEntry.self, from: data) else { return nil }

        let matchingID = raw.matchingEntryTitle.flatMap { title in
            existingEntries.first { $0.title.lowercased() == title.lowercased() }?.id
        }

        return ProcessedEntry(
            title: raw.title,
            content: raw.content,
            tags: raw.tags ?? [],
            matchingEntryID: matchingID
        )
    }
}
