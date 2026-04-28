import Foundation

struct OpenAIClient: AIService {
    let apiKey: String

    func ask(question: String, context: [KnowledgeEntry]) async throws -> AIResponse {
        let body: [String: Any] = [
            "model": AIProvider.openAI.modelName,
            "messages": [
                ["role": "system", "content": AIPrompts.systemPrompt],
                ["role": "user", "content": AIPrompts.buildUserMessage(question: question, entries: context)]
            ],
            "response_format": ["type": "json_object"],
            "temperature": 0.3
        ]

        let text = try await callAPI(body: body)
        return AIResponseParser.parse(text, entries: context)
    }

    func processNewEntry(rawText: String, existingEntries: [KnowledgeEntry]) async throws -> ProcessedEntry {
        let body: [String: Any] = [
            "model": AIProvider.openAI.modelName,
            "messages": [
                ["role": "system", "content": AIPrompts.processEntrySystemPrompt],
                ["role": "user", "content": AIPrompts.buildProcessEntryMessage(rawText: rawText, existingEntries: existingEntries)]
            ],
            "response_format": ["type": "json_object"],
            "temperature": 0.3
        ]

        let text = try await callAPI(body: body)
        guard let entry = AIResponseParser.parseProcessedEntry(text, existingEntries: existingEntries) else {
            throw AIError.decodingError("Could not parse entry from AI response")
        }
        return entry
    }

    private func callAPI(body: [String: Any]) async throws -> String {
        guard !apiKey.isEmpty else { throw AIError.noAPIKey }

        var request = URLRequest(url: URL(string: "https://api.openai.com/v1/chat/completions")!)
        request.httpMethod = "POST"
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
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

        struct OpenAIResponse: Decodable {
            struct Choice: Decodable {
                struct Message: Decodable {
                    let content: String
                }
                let message: Message
            }
            let choices: [Choice]
        }

        do {
            let decoded = try JSONDecoder().decode(OpenAIResponse.self, from: data)
            guard let content = decoded.choices.first?.message.content else {
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
