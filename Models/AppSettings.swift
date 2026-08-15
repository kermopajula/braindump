import Foundation
import SwiftUI

final class AppSettings: ObservableObject {
    @AppStorage("hasSeenPrivacyNotice") var hasSeenPrivacyNotice: Bool = false

    /// Nil when the on-device model is ready to use, otherwise a user-facing
    /// explanation of why it isn't.
    var aiUnavailableMessage: String? {
        if #available(iOS 26.0, *) {
            return FoundationModelsClient.availabilityMessage
        }
        return "Apple Intelligence requires iOS 26 or later."
    }

    /// True when the on-device model can actually be used right now.
    var isAIReady: Bool { aiUnavailableMessage == nil }
}
