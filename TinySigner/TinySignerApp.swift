import SwiftData
import SwiftUI

@main
struct TinySignerApp: App {
    var sharedModelContainer: ModelContainer = {
        let schema = Schema([
            SignatureAsset.self,
            SignerProfile.self,
            RecentDocument.self
        ])
        let modelConfiguration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)

        do {
            return try ModelContainer(for: schema, configurations: [modelConfiguration])
        } catch {
            fatalError("Could not create ModelContainer: \(error)")
        }
    }()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .frame(minWidth: 980, minHeight: 680)
        }
        .modelContainer(sharedModelContainer)
        .commands {
            CommandGroup(replacing: .newItem) { }
        }
    }
}
