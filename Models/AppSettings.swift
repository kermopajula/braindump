import Foundation
import SwiftUI

final class AppSettings: ObservableObject {
    @AppStorage("selectedProvider") private var selectedProviderRaw: String = AIProvider.appleFoundation.rawValue
    @AppStorage("apiKey") var apiKey: String = ""
    @AppStorage("hasSeenPrivacyNotice") var hasSeenPrivacyNotice: Bool = false

    var selectedProvider: AIProvider {
        get { AIProvider(rawValue: selectedProviderRaw) ?? .appleFoundation }
        set { selectedProviderRaw = newValue.rawValue }
    }

    /// True when the selected provider can actually be used right now.
    /// Apple Intelligence needs no key; external providers need an API key.
    var isAIReady: Bool {
        if selectedProvider.requiresAPIKey {
            return !apiKey.isEmpty
        }
        return true
    }
}
