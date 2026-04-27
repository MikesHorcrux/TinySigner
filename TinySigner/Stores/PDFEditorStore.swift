import AppKit
import Combine
import Foundation
import PDFKit

@MainActor
final class PDFEditorStore: ObservableObject {
    @Published var document: PDFDocument?
    @Published var documentURL: URL?
    @Published var fields: [PlacedField] = []
    @Published var selectedFieldID: UUID?
    @Published var activeTool: SigningTool = .select
    @Published var zoomScale: CGFloat = 1.0
    @Published var currentPageIndex: Int = 0
    @Published var statusMessage: String = "Open a PDF to begin."
    @Published var lastError: String?
    @Published var refreshToken = UUID()
    @Published private(set) var canUndo = false
    @Published private(set) var canRedo = false

    let service = PDFDocumentService()
    private var undoStack: [[PlacedField]] = []
    private var redoStack: [[PlacedField]] = []
    private var dragSnapshot: [PlacedField]?

    var hasDocument: Bool { document != nil }
    var pageCount: Int { document?.pageCount ?? 0 }
    var selectedField: PlacedField? { selectedFieldID.flatMap(field(withID:)) }

    func openPDF(from url: URL) throws {
        if let document {
            PDFDocumentService.removeTinySignerPreviewAnnotations(from: document)
        }
        let opened = try service.openDocument(from: url)
        load(document: opened, sourceURL: url, statusName: url.lastPathComponent)
    }

    func openDemoPDF(named title: String = "TinySigner Fixture") {
        if let document {
            PDFDocumentService.removeTinySignerPreviewAnnotations(from: document)
        }
        load(document: service.makeDemoDocument(title: title), sourceURL: nil, statusName: title)
    }

    private func load(document opened: PDFDocument, sourceURL: URL?, statusName: String) {
        document = opened
        documentURL = sourceURL
        fields = []
        selectedFieldID = nil
        activeTool = .select
        currentPageIndex = 0
        undoStack.removeAll()
        redoStack.removeAll()
        updateUndoState()
        refreshToken = UUID()
        statusMessage = "Opened \(statusName). Add a signature, date, text, or checkbox."
    }

    func addField(kind: PlacedField.Kind, pageIndex: Int, at point: CGPoint, pageBounds: CGRect, profile: SignerProfile?, defaultSignatureAssetID: UUID?, defaultInitialsAssetID: UUID?) {
        let size = kind.defaultSize
        let rect = CGRect(origin: .zero, size: size).centered(on: point, clampedTo: pageBounds).snapped(to: 2)
        let field = PlacedField(
            kind: kind,
            pageIndex: pageIndex,
            rectInPageSpace: rect,
            text: defaultText(for: kind, profile: profile),
            style: defaultStyle(for: kind),
            signatureAssetID: assetID(for: kind, signatureID: defaultSignatureAssetID, initialsID: defaultInitialsAssetID)
        )
        applyFields(fields + [field], recordUndo: true)
        selectedFieldID = field.id
        activeTool = .select
        statusMessage = "Placed \(kind.title.lowercased()) on page \(pageIndex + 1)."
    }

    func updateFieldRect(id: UUID, rect: CGRect, pageBounds: CGRect, recordUndo: Bool = true) {
        guard let index = fields.firstIndex(where: { $0.id == id }) else { return }
        var updated = fields
        updated[index].rectInPageSpace = rect.clamped(to: pageBounds).snapped(to: 2)
        applyFields(updated, recordUndo: recordUndo)
    }

    func updateSelectedField(_ transform: (inout PlacedField) -> Void) {
        guard let selectedFieldID, let index = fields.firstIndex(where: { $0.id == selectedFieldID }) else { return }
        var updated = fields
        transform(&updated[index])
        applyFields(updated, recordUndo: true)
    }

    func deleteSelectedField() {
        guard let selectedFieldID else { return }
        deleteField(id: selectedFieldID)
    }

    func deleteField(id: UUID) {
        guard fields.contains(where: { $0.id == id }) else { return }
        applyFields(fields.filter { $0.id != id }, recordUndo: true)
        if selectedFieldID == id {
            selectedFieldID = nil
        }
        statusMessage = "Removed field."
    }

    func beginFieldDrag() {
        guard dragSnapshot == nil else { return }
        dragSnapshot = fields
    }

    func finishFieldDrag() {
        guard let snapshot = dragSnapshot else { return }
        if snapshot != fields {
            undoStack.append(snapshot)
            redoStack.removeAll()
            updateUndoState()
        }
        dragSnapshot = nil
    }

    func undo() {
        guard let previous = undoStack.popLast() else { return }
        redoStack.append(fields)
        fields = previous
        selectedFieldID = fields.last?.id
        refreshToken = UUID()
        updateUndoState()
        statusMessage = "Undid the last edit."
    }

    func redo() {
        guard let next = redoStack.popLast() else { return }
        undoStack.append(fields)
        fields = next
        selectedFieldID = fields.last?.id
        refreshToken = UUID()
        updateUndoState()
        statusMessage = "Redid the last edit."
    }

    func zoomIn() {
        zoomScale = min(zoomScale + 0.15, 3.0)
    }

    func zoomOut() {
        zoomScale = max(zoomScale - 0.15, 0.35)
    }

    func resetZoom() {
        zoomScale = 1.0
    }

    func exportSignedPDF(to outputURL: URL, signatureAssets: [SignatureAsset]) throws {
        guard let document else { throw PDFDocumentService.ServiceError.missingDocument }
        let assets = Dictionary(uniqueKeysWithValues: signatureAssets.compactMap { asset -> (UUID, Data)? in
            guard let imageData = asset.imageData else { return nil }
            return (asset.id, imageData)
        })
        try service.exportFlattenedPDF(document: document, fields: fields, signatureAssetsByID: assets, to: outputURL)
        refreshToken = UUID()
        statusMessage = "Exported signed PDF to \(outputURL.lastPathComponent)."
    }

    func field(withID id: UUID) -> PlacedField? {
        fields.first { $0.id == id }
    }

    private func applyFields(_ newFields: [PlacedField], recordUndo: Bool) {
        if recordUndo {
            undoStack.append(fields)
            redoStack.removeAll()
        }
        fields = newFields
        refreshToken = UUID()
        updateUndoState()
    }

    private func updateUndoState() {
        canUndo = !undoStack.isEmpty
        canRedo = !redoStack.isEmpty
    }

    private func defaultText(for kind: PlacedField.Kind, profile: SignerProfile?) -> String {
        switch kind {
        case .signature:
            let name = profile?.fullName.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            return name.isEmpty ? "Signature" : name
        case .initials:
            let initials = profile?.initials.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            return initials.isEmpty ? "Initials" : initials
        case .text:
            return "Text"
        case .date:
            return Self.formattedDate(using: profile?.preferredDateFormat)
        case .checkbox:
            return "on"
        }
    }

    private func defaultStyle(for kind: PlacedField.Kind) -> FieldStyle {
        switch kind {
        case .signature, .initials: .signature
        case .checkbox: .checkbox
        case .text, .date: .default
        }
    }

    private func assetID(for kind: PlacedField.Kind, signatureID: UUID?, initialsID: UUID?) -> UUID? {
        switch kind {
        case .signature: signatureID
        case .initials: initialsID
        case .text, .date, .checkbox: nil
        }
    }

    static func formattedDate(using dateFormat: String?) -> String {
        let formatter = DateFormatter()
        formatter.locale = .current
        formatter.dateFormat = (dateFormat?.isEmpty == false) ? dateFormat : "MMM d, yyyy"
        return formatter.string(from: Date())
    }
}
