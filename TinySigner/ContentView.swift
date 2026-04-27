import AppKit
import PDFKit
import SwiftData
import SwiftUI
import UniformTypeIdentifiers

struct ContentView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \SignerProfile.updatedAt, order: .reverse) private var profiles: [SignerProfile]
    @Query(sort: \SignatureAsset.updatedAt, order: .reverse) private var signatureAssets: [SignatureAsset]
    @Query(sort: \RecentDocument.lastOpenedAt, order: .reverse) private var recentDocuments: [RecentDocument]
    @StateObject private var editor = PDFEditorStore()
    @State private var didHandleLaunchArguments = false

    private var activeProfile: SignerProfile? { profiles.first }

    var body: some View {
        NavigationSplitView {
            SidebarView(editor: editor, recentDocuments: recentDocuments, openRecent: openRecent)
                .navigationSplitViewColumnWidth(min: 210, ideal: 240, max: 300)
        } detail: {
            if editor.hasDocument {
                HSplitView {
                    EditorWorkspaceView(editor: editor, profile: activeProfile, signatureAssets: signatureAssets)
                    InspectorPanelView(editor: editor, profile: activeProfile, signatureAssets: signatureAssets)
                }
            } else {
                WelcomeView(recentDocuments: recentDocuments, openPDF: openPDF, openRecent: openRecent)
            }
        }
        .toolbar {
            ToolbarItemGroup(placement: .primaryAction) {
                Button(action: openPDF) {
                    Label("Open PDF", systemImage: "doc.badge.plus")
                }
                .keyboardShortcut("o", modifiers: .command)

                Button(action: exportSignedPDF) {
                    Label("Export Signed", systemImage: "square.and.arrow.down")
                }
                .accessibilityIdentifier("exportSignedButton")
                .disabled(!editor.hasDocument)
                .keyboardShortcut("e", modifiers: [.command, .shift])
            }

            ToolbarItemGroup {
                Button(action: editor.undo) {
                    Label("Undo", systemImage: "arrow.uturn.backward")
                }
                .disabled(!editor.canUndo)
                .keyboardShortcut("z", modifiers: .command)

                Button(action: editor.redo) {
                    Label("Redo", systemImage: "arrow.uturn.forward")
                }
                .disabled(!editor.canRedo)
                .keyboardShortcut("z", modifiers: [.command, .shift])
            }
        }
        .alert("TinySigner", isPresented: Binding(
            get: { editor.lastError != nil },
            set: { isPresented in if !isPresented { editor.lastError = nil } }
        )) {
            Button("OK", role: .cancel) { editor.lastError = nil }
        } message: {
            Text(editor.lastError ?? "")
        }
        .onAppear {
            ensureProfileExists()
            handleLaunchArgumentsIfNeeded()
        }
    }

    private func openPDF() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.pdf]
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        panel.canChooseFiles = true
        panel.message = "Choose a PDF to sign locally in TinySigner."

        guard panel.runModal() == .OK, let url = panel.url else { return }
        openURL(url, storeRecentDocument: true)
    }

    private func openRecent(_ recent: RecentDocument) {
        do {
            let url = try editor.service.resolveSecurityScopedBookmark(recent.bookmarkData)
            let canAccess = url.startAccessingSecurityScopedResource()
            defer {
                if canAccess { url.stopAccessingSecurityScopedResource() }
            }
            openURL(url, storeRecentDocument: true)
        } catch {
            editor.lastError = error.localizedDescription
        }
    }

    private func openURL(_ url: URL, storeRecentDocument: Bool) {
        do {
            let canAccess = url.startAccessingSecurityScopedResource()
            defer {
                if canAccess { url.stopAccessingSecurityScopedResource() }
            }

            try editor.openPDF(from: url)
            if storeRecentDocument {
                try rememberRecentDocument(url)
            }
        } catch {
            editor.lastError = error.localizedDescription
        }
    }

    private func exportSignedPDF() {
        let panel = NSSavePanel()
        panel.allowedContentTypes = [.pdf]
        panel.canCreateDirectories = true
        panel.nameFieldStringValue = editor.service.defaultSignedFilename(for: editor.documentURL)
        panel.message = "Export a flattened signed copy. Your original PDF will not be changed."

        guard panel.runModal() == .OK, let url = panel.url else { return }
        do {
            try editor.exportSignedPDF(to: url, signatureAssets: signatureAssets)
        } catch {
            editor.lastError = error.localizedDescription
        }
    }

    private func rememberRecentDocument(_ url: URL) throws {
        let bookmark = try editor.service.makeSecurityScopedBookmark(for: url)
        if let existing = recentDocuments.first(where: { $0.originalPath == url.path }) {
            existing.displayName = url.lastPathComponent
            existing.bookmarkData = bookmark
            existing.pageCount = editor.pageCount
            existing.lastOpenedAt = Date()
        } else {
            modelContext.insert(RecentDocument(
                displayName: url.lastPathComponent,
                originalPath: url.path,
                pageCount: editor.pageCount,
                bookmarkData: bookmark
            ))
        }
        try? modelContext.save()
    }

    private func ensureProfileExists() {
        guard profiles.isEmpty else { return }
        let profile = SignerProfile()
        modelContext.insert(profile)
        try? modelContext.save()
    }

    private func handleLaunchArgumentsIfNeeded() {
        guard !didHandleLaunchArguments else { return }
        didHandleLaunchArguments = true

        let arguments = ProcessInfo.processInfo.arguments
        let environment = ProcessInfo.processInfo.environment
        let isUITest = arguments.contains("--uitest") || environment["TINYSIGNER_UI_TEST"] == "1"
        let shouldStayEmpty = arguments.contains("--uitest-empty") || environment["TINYSIGNER_UI_TEST_EMPTY"] == "1"

        if let path = environment["TINYSIGNER_OPEN_PDF"] ?? launchArgumentValue(named: "--open-pdf", in: arguments) {
            openURL(URL(fileURLWithPath: path), storeRecentDocument: false)
        }

        if isUITest && !shouldStayEmpty && !editor.hasDocument {
            editor.lastError = nil
            editor.openDemoPDF(named: "TinySigner UI Fixture")
        }
    }

    private func launchArgumentValue(named name: String, in arguments: [String]) -> String? {
        guard let index = arguments.firstIndex(of: name), arguments.indices.contains(index + 1) else { return nil }
        return arguments[index + 1]
    }
}

#Preview {
    ContentView()
        .modelContainer(for: [SignatureAsset.self, SignerProfile.self, RecentDocument.self], inMemory: true)
}
