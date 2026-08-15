import Foundation
#if canImport(FoundationModels)
import FoundationModels
#endif

/// On-device AI client backed by Apple's Foundation Models framework.
/// Free, private, and key-less, but requires iOS 26+ on an Apple Intelligence-capable device.
@available(iOS 26.0, macOS 26.0, *)
final class FoundationModelsClient: AIService {

    static var availabilityMessage: String? {
        let model = SystemLanguageModel.default
        switch model.availability {
        case .available:
            return nil
        case .unavailable(.deviceNotEligible):
            return "This device doesn't support Apple Intelligence."
        case .unavailable(.appleIntelligenceNotEnabled):
            return "Apple Intelligence is off. Enable it in Settings → Apple Intelligence & Siri."
        case .unavailable(.modelNotReady):
            return "The on-device model is still downloading. Try again in a few minutes."
        case .unavailable:
            return "Apple Intelligence is unavailable on this device."
        }
    }

    static var isAvailable: Bool {
        if case .available = SystemLanguageModel.default.availability {
            return true
        }
        return false
    }

    func ask(question: String, context: [KnowledgeEntry]) async throws -> AIResponse {
        try ensureAvailable()
        let session = LanguageModelSession(instructions: AIPrompts.systemPrompt)
        let userMessage = AIPrompts.buildUserMessage(question: question, entries: context)

        do {
            let response = try await session.respond(
                to: userMessage,
                generating: GeneratedAskResponse.self
            )
            let raw = response.content
            let updates = raw.suggestedUpdates.map { update in
                KnowledgeUpdate(
                    existingEntryID: update.existingEntryID.flatMap { $0.isEmpty ? nil : UUID(uuidString: $0) },
                    title: update.title,
                    content: update.content,
                    tags: update.tags,
                    reason: update.reason
                )
            }
            return AIResponse(answer: raw.answer, suggestedUpdates: updates)
        } catch {
            throw AIError.networkError(error)
        }
    }

    func processNewEntry(rawText: String, existingEntries: [KnowledgeEntry]) async throws -> ProcessedEntry {
        try ensureAvailable()
        let session = LanguageModelSession(instructions: AIPrompts.processEntrySystemPrompt)
        let userMessage = AIPrompts.buildProcessEntryMessage(rawText: rawText, existingEntries: existingEntries)

        do {
            let response = try await session.respond(
                to: userMessage,
                generating: GeneratedProcessedEntry.self
            )
            let raw = response.content
            let matchingID = raw.matchingEntryTitle.flatMap { title -> UUID? in
                guard !title.isEmpty else { return nil }
                return existingEntries.first { $0.title.lowercased() == title.lowercased() }?.id
            }
            return ProcessedEntry(
                title: raw.title,
                content: raw.content,
                tags: raw.tags,
                matchingEntryID: matchingID
            )
        } catch {
            throw AIError.networkError(error)
        }
    }

    private func ensureAvailable() throws {
        if let message = Self.availabilityMessage {
            throw AIError.foundationModelsUnavailable(message)
        }
    }
}

// MARK: - Generable structured output

@available(iOS 26.0, macOS 26.0, *)
@Generable
struct GeneratedAskResponse {
    @Guide(description: "Concise, direct answer based only on the provided knowledge base entries.")
    let answer: String

    @Guide(description: "Updates to existing entries when the question contains new info that conflicts with or adds to them. Empty when nothing needs updating.")
    let suggestedUpdates: [GeneratedUpdate]

    @Generable
    struct GeneratedUpdate {
        @Guide(description: "UUID of the existing entry to update, or empty string to create a new entry.")
        let existingEntryID: String?
        let title: String
        let content: String
        let tags: [String]
        let reason: String
    }
}

@available(iOS 26.0, macOS 26.0, *)
@Generable
struct GeneratedProcessedEntry {
    @Guide(description: "A short descriptive title for the entry.")
    let title: String

    @Guide(description: "The cleaned-up information.")
    let content: String

    @Guide(description: "Relevant tags for the entry.")
    let tags: [String]

    @Guide(description: "Exact title of an existing entry ONLY when the new input is about the same specific subject (same item, same measurement, same instructions). A shared category like 'item location' is NOT a match — different items get different entries. Empty string when in doubt or when no existing entry is about the same subject.")
    let matchingEntryTitle: String?
}
