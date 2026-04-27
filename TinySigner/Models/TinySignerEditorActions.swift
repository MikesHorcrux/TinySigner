import SwiftUI

struct TinySignerEditorActions {
    var openPDF: () -> Void
    var exportSignedPDF: () -> Void
    var undo: () -> Void
    var redo: () -> Void
    var deleteField: () -> Void
    var zoomIn: () -> Void
    var zoomOut: () -> Void
    var resetZoom: () -> Void
    var acceptHighConfidenceSuggestions: () -> Void
    var setTool: (SigningTool) -> Void

    var canExport: Bool
    var canUndo: Bool
    var canRedo: Bool
    var canDelete: Bool
    var canAcceptSuggestions: Bool
    var activeTool: SigningTool
}

private struct TinySignerEditorActionsKey: FocusedValueKey {
    typealias Value = TinySignerEditorActions
}

extension FocusedValues {
    var tinySignerEditorActions: TinySignerEditorActions? {
        get { self[TinySignerEditorActionsKey.self] }
        set { self[TinySignerEditorActionsKey.self] = newValue }
    }
}
