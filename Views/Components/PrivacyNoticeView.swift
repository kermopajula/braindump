import SwiftUI

struct PrivacyNoticeView: View {
    @EnvironmentObject var settings: AppSettings
    @Environment(\.dismiss) var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    Image(systemName: "lock.shield.fill")
                        .font(.system(size: 60))
                        .foregroundColor(.accentColor)
                        .frame(maxWidth: .infinity)
                        .padding(.top, 20)

                    VStack(spacing: 4) {
                        Text("Your Personal Knowledge Vault")
                            .font(.title2.bold())
                        Text("Your data stays on your device")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    .frame(maxWidth: .infinity, alignment: .center)

                    VStack(alignment: .leading, spacing: 16) {
                        privacyItem(
                            icon: "iphone",
                            title: "Local Storage Only",
                            description: "Your knowledge base is stored as a file on your device. It is never uploaded to any server."
                        )

                        privacyItem(
                            icon: "network.slash",
                            title: "No Analytics or Tracking",
                            description: "BrainDump does not collect any analytics, usage data, or personal information."
                        )

                        privacyItem(
                            icon: "key",
                            title: "Your API Key",
                            description: "Your API key is stored locally on your device. It is only used to communicate directly with your chosen AI provider (OpenAI or Anthropic)."
                        )

                        privacyItem(
                            icon: "brain.head.profile",
                            title: "AI Queries",
                            description: "When you use the Ask feature, your knowledge base entries are sent to your chosen AI provider to generate answers. This is the only time data leaves your device, and it goes directly to the provider you selected."
                        )

                        privacyItem(
                            icon: "mic",
                            title: "Voice Recognition",
                            description: "Speech recognition uses Apple's on-device processing when available. No audio is sent to external servers."
                        )

                        privacyItem(
                            icon: "square.and.arrow.up",
                            title: "Export Control",
                            description: "You are in full control of your data. Knowledge can only leave your device when you explicitly export it."
                        )
                    }
                    .padding(.horizontal)
                }
                .padding()
            }
            .navigationTitle("Privacy")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("I Understand") {
                        settings.hasSeenPrivacyNotice = true
                        dismiss()
                    }
                    .bold()
                }
            }
        }
    }

    private func privacyItem(icon: String, title: String, description: String) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundColor(.accentColor)
                .frame(width: 30)

            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.subheadline.bold())
                Text(description)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
    }
}
