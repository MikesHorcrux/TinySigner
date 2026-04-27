import SwiftUI

struct TinySignerCommands: Commands {
    @FocusedValue(\.tinySignerEditorActions) private var actions

    var body: some Commands {
        CommandGroup(replacing: .newItem) {
            Button("New Window") {
                TinySignerAppState.shared.showMainWindow()
            }
            .keyboardShortcut("n", modifiers: .command)

            Divider()

            Button("Open PDF...") {
                actions?.openPDF()
            }
            .keyboardShortcut("o", modifiers: .command)
            .disabled(actions == nil)

            Button("Export Signed PDF...") {
                actions?.exportSignedPDF()
            }
            .keyboardShortcut("e", modifiers: [.command, .shift])
            .disabled(actions?.canExport != true)
        }

        CommandGroup(replacing: .undoRedo) {
            Button("Undo") {
                actions?.undo()
            }
            .keyboardShortcut("z", modifiers: .command)
            .disabled(actions?.canUndo != true)

            Button("Redo") {
                actions?.redo()
            }
            .keyboardShortcut("z", modifiers: [.command, .shift])
            .disabled(actions?.canRedo != true)
        }

        CommandGroup(after: .pasteboard) {
            Button("Delete Field") {
                actions?.deleteField()
            }
            .keyboardShortcut(.delete, modifiers: [])
            .disabled(actions?.canDelete != true)
        }

        CommandMenu("View") {
            Button("Zoom In") {
                actions?.zoomIn()
            }
            .keyboardShortcut("+", modifiers: .command)
            .disabled(actions == nil)

            Button("Zoom Out") {
                actions?.zoomOut()
            }
            .keyboardShortcut("-", modifiers: .command)
            .disabled(actions == nil)

            Button("Actual Size") {
                actions?.resetZoom()
            }
            .keyboardShortcut("0", modifiers: .command)
            .disabled(actions == nil)
        }

        CommandMenu("Tools") {
            toolButton(.select, shortcut: "1")
            toolButton(.signature, shortcut: "2")
            toolButton(.initials, shortcut: "3")
            toolButton(.text, shortcut: "4")
            toolButton(.date, shortcut: "5")
            toolButton(.checkbox, shortcut: "6")

            Divider()

            Button("Accept High-Confidence Suggestions") {
                actions?.acceptHighConfidenceSuggestions()
            }
            .keyboardShortcut("a", modifiers: [.command, .shift])
            .disabled(actions?.canAcceptSuggestions != true)
        }
    }

    private func toolButton(_ tool: SigningTool, shortcut: KeyEquivalent) -> some View {
        Button {
            actions?.setTool(tool)
        } label: {
            Label(tool.title, systemImage: tool.systemImage)
        }
        .keyboardShortcut(shortcut, modifiers: [.command, .option])
        .disabled(actions == nil)
    }
}
