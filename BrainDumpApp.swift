import SwiftUI

@main
struct BrainDumpApp: App {
    @StateObject private var store = KnowledgeStore()
    @StateObject private var settings = AppSettings()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(store)
                .environmentObject(settings)
        }
    }
}
