import AppKit
import SwiftData
import SwiftUI

@main
struct TinySignerApp: App {
    @NSApplicationDelegateAdaptor(TinySignerAppDelegate.self) private var appDelegate

    private let appState = TinySignerAppState.shared

    var body: some Scene {
        Settings {
            SettingsView()
                .modelContainer(appState.modelContainer)
        }
        .commands {
            TinySignerCommands()
        }
    }
}

@MainActor
final class TinySignerAppState {
    static let shared = TinySignerAppState()
    static let minimumMainWindowSize = NSSize(width: 1120, height: 720)
    static let defaultMainWindowSize = NSSize(width: 1240, height: 820)

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
            .frame(minWidth: Self.minimumMainWindowSize.width, minHeight: Self.minimumMainWindowSize.height)
            .modelContainer(modelContainer)
        let hostingController = NSHostingController(rootView: rootView)
        let window = NSWindow(
            contentRect: NSRect(origin: .zero, size: Self.defaultMainWindowSize),
            styleMask: [.titled, .closable, .miniaturizable, .resizable],
            backing: .buffered,
            defer: false
        )
        window.title = "TinySigner"
        window.identifier = NSUserInterfaceItemIdentifier("main")
        window.minSize = Self.minimumMainWindowSize
        window.toolbarStyle = .unified
        window.titlebarSeparatorStyle = .line
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
