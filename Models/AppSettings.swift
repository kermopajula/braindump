import Foundation
import SwiftUI

final class AppSettings: ObservableObject {
    @AppStorage("selectedProvider") private var selectedProviderRaw: String = AIProvider.openAI.rawValue
    @AppStorage("apiKey") var apiKey: String = ""
    @AppStorage("hasSeenPrivacyNotice") var hasSeenPrivacyNotice: Bool = false

    var selectedProvider: AIProvider {
        get { AIProvider(rawValue: selectedProviderRaw) ?? .openAI }
        set { selectedProviderRaw = newValue.rawValue }
    }
}
