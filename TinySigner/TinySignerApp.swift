import AppKit
import SwiftData
import SwiftUI

@main
struct TinySignerApp: App {
    @NSApplicationDelegateAdaptor(TinySignerAppDelegate.self) private var appDelegate

    private let appState = TinySignerAppState.shared

    var body: some Scene {
        Settings {
            EmptyView()
        }
        .commands {
            CommandGroup(replacing: .newItem) {
                Button("New Window") {
                    appState.showMainWindow()
                }
                .keyboardShortcut("n", modifiers: .command)
            }
        }
    }
}

@MainActor
final class TinySignerAppState {
    static let shared = TinySignerAppState()

    let modelContainer: ModelContainer
    private var mainWindowController: NSWindowController?

    private init() {
        modelContainer = Self.makeModelContainer()
    }

    func showMainWindow() {
        if let window = mainWindowController?.window {
            window.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            return
        }

        let rootView = ContentView()
            .frame(minWidth: 980, minHeight: 680)
            .modelContainer(modelContainer)
        let hostingController = NSHostingController(rootView: rootView)
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 1180, height: 760),
            styleMask: [.titled, .closable, .miniaturizable, .resizable],
            backing: .buffered,
            defer: false
        )
        window.title = "TinySigner"
        window.identifier = NSUserInterfaceItemIdentifier("main")
        window.isReleasedWhenClosed = false
        window.contentViewController = hostingController
        window.setFrameAutosaveName("TinySignerMainWindow")
        window.center()

        mainWindowController = NSWindowController(window: window)
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    private static func makeModelContainer() -> ModelContainer {
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
    }
}

final class TinySignerAppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        Task { @MainActor in
            TinySignerAppState.shared.showMainWindow()
        }
    }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        if !flag {
            Task { @MainActor in
                TinySignerAppState.shared.showMainWindow()
            }
        }
        return true
    }
}
