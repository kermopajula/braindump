import Foundation

enum AIProvider: String, Codable, CaseIterable, Identifiable {
    case appleFoundation = "Apple Intelligence"
    case openAI = "OpenAI"
    case anthropic = "Anthropic"

    var id: String { rawValue }

    var modelName: String {
        switch self {
        case .appleFoundation: return "Apple on-device model"
        case .openAI: return "gpt-4o"
        case .anthropic: return "claude-sonnet-4-20250514"
        }
    }

    var displayName: String { rawValue }

    var requiresAPIKey: Bool {
        switch self {
        case .appleFoundation: return false
        case .openAI, .anthropic: return true
        }
    }
}
