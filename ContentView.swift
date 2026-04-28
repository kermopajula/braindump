import SwiftUI

struct ContentView: View {
    @EnvironmentObject var settings: AppSettings
    @State private var showPrivacyNotice = false

    var body: some View {
        TabView {
            AddKnowledgeView()
                .tabItem {
                    Label("Add", systemImage: "plus.circle.fill")
                }

            KnowledgeListView()
                .tabItem {
                    Label("Knowledge", systemImage: "book.fill")
                }

            AskView()
                .tabItem {
                    Label("Ask", systemImage: "brain.head.profile")
                }

            SettingsView()
                .tabItem {
                    Label("Settings", systemImage: "gear")
                }
        }
        .onAppear {
            if !settings.hasSeenPrivacyNotice {
                showPrivacyNotice = true
            }
        }
        .sheet(isPresented: $showPrivacyNotice) {
            PrivacyNoticeView()
        }
    }
}
