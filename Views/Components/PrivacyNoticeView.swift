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
                            icon: "brain.head.profile",
                            title: "On-Device AI by Default",
                            description: "BrainDump uses Apple Intelligence's on-device model by default. Your knowledge never leaves your device when answering questions, and no API key is required."
                        )

                        privacyItem(
                            icon: "key",
                            title: "Optional Cloud Providers",
                            description: "If you want a more capable model, you can switch to OpenAI or Anthropic in Settings and add your own API key. Your key is stored only on this device. When you use the Ask feature with a cloud provider, your knowledge base entries are sent to that provider to generate the answer."
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
