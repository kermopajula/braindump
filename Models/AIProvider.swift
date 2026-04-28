import Foundation

enum AIProvider: String, Codable, CaseIterable, Identifiable {
    case openAI = "OpenAI"
    case anthropic = "Anthropic"

    var id: String { rawValue }

    var modelName: String {
        switch self {
        case .openAI: return "gpt-4o"
        case .anthropic: return "claude-sonnet-4-20250514"
        }
    }

    var displayName: String { rawValue }
}
