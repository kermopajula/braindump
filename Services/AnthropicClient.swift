import Foundation

struct AnthropicClient: AIService {
    let apiKey: String

    func ask(question: String, context: [KnowledgeEntry]) async throws -> AIResponse {
        let body: [String: Any] = [
            "model": AIProvider.anthropic.modelName,
            "max_tokens": 2048,
            "system": AIPrompts.systemPrompt,
            "messages": [
                ["role": "user", "content": AIPrompts.buildUserMessage(question: question, entries: context)]
            ]
        ]

        let text = try await callAPI(body: body)
        return AIResponseParser.parse(text, entries: context)
    }

    func processNewEntry(rawText: String, existingEntries: [KnowledgeEntry]) async throws -> ProcessedEntry {
        let body: [String: Any] = [
            "model": AIProvider.anthropic.modelName,
            "max_tokens": 1024,
            "system": AIPrompts.processEntrySystemPrompt,
            "messages": [
                ["role": "user", "content": AIPrompts.buildProcessEntryMessage(rawText: rawText, existingEntries: existingEntries)]
            ]
        ]

        let text = try await callAPI(body: body)
        guard let entry = AIResponseParser.parseProcessedEntry(text, existingEntries: existingEntries) else {
            throw AIError.decodingError("Could not parse entry from AI response")
        }
        return entry
    }

    private func callAPI(body: [String: Any]) async throws -> String {
        guard !apiKey.isEmpty else { throw AIError.noAPIKey }

        var request = URLRequest(url: URL(string: "https://api.anthropic.com/v1/messages")!)
        request.httpMethod = "POST"
        request.setValue(apiKey, forHTTPHeaderField: "x-api-key")
        request.setValue("2023-06-01", forHTTPHeaderField: "anthropic-version")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, response): (Data, URLResponse)
        do {
            (data, response) = try await URLSession.shared.data(for: request)
        } catch {
            throw AIError.networkError(error)
        }

        guard let httpResponse = response as? HTTPURLResponse else {
            throw AIError.invalidResponse(0)
        }
        guard httpResponse.statusCode == 200 else {
            throw AIError.invalidResponse(httpResponse.statusCode)
        }

        struct AnthropicResponse: Decodable {
            struct Content: Decodable {
                let text: String
            }
            let content: [Content]
        }

        do {
            let decoded = try JSONDecoder().decode(AnthropicResponse.self, from: data)
            guard let content = decoded.content.first?.text else {
                throw AIError.decodingError("No content in response")
            }
            return content
        } catch let error as AIError {
            throw error
        } catch {
            throw AIError.decodingError(error.localizedDescription)
        }
    }
}
