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
    @Published var fieldSuggestions: [DetectedFieldSuggestion] = []
    @Published var exportReceipt: ExportReceipt?
    @Published private(set) var canUndo = false
    @Published private(set) var canRedo = false

    let service = PDFDocumentService()
    private let detectionService = PDFFieldDetectionService()
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
        fieldSuggestions = detectionService.detectSuggestions(in: opened)
        selectedFieldID = nil
        activeTool = .select
        currentPageIndex = 0
        undoStack.removeAll()
        redoStack.removeAll()
        updateUndoState()
        refreshToken = UUID()
        statusMessage = openStatusMessage(for: statusName, suggestionCount: fieldSuggestions.count)
    }

    func addField(kind: PlacedField.Kind, pageIndex: Int, at point: CGPoint, pageBounds: CGRect, profile: SignerProfile?, defaultSignatureAssetID: UUID?, defaultInitialsAssetID: UUID?) {
        let snappedSuggestion = nearestSuggestion(kind: kind, pageIndex: pageIndex, point: point)
        let rect = snappedSuggestion?.rectInPageSpace ?? defaultRect(for: kind, at: point, size: kind.defaultSize, pageBounds: pageBounds)
        let field = makeField(
            kind: kind,
            pageIndex: pageIndex,
            rect: rect,
            profile: profile,
            defaultSignatureAssetID: defaultSignatureAssetID,
            defaultInitialsAssetID: defaultInitialsAssetID
        )

        if let snappedSuggestion {
            fieldSuggestions.removeAll { $0.id == snappedSuggestion.id }
        }
        applyFields(fields + [field], recordUndo: true)
        selectedFieldID = field.id
        activeTool = .select
        statusMessage = snappedSuggestion == nil
            ? "Placed \(kind.title.lowercased()) on page \(pageIndex + 1)."
            : "Placed \(kind.title.lowercased()) from smart suggestion on page \(pageIndex + 1)."
    }

    @discardableResult
    func acceptSuggestion(id: UUID, profile: SignerProfile? = nil, defaultSignatureAssetID: UUID? = nil, defaultInitialsAssetID: UUID? = nil) -> Bool {
        guard let suggestion = fieldSuggestions.first(where: { $0.id == id }) else { return false }
        let field = makeField(
            kind: suggestion.kind,
            pageIndex: suggestion.pageIndex,
            rect: suggestion.rectInPageSpace,
            profile: profile,
            defaultSignatureAssetID: defaultSignatureAssetID,
            defaultInitialsAssetID: defaultInitialsAssetID
        )
        fieldSuggestions.removeAll { $0.id == id }
        applyFields(fields + [field], recordUndo: true)
        selectedFieldID = field.id
        activeTool = .select
        statusMessage = "Accepted \(suggestion.kind.title.lowercased()) suggestion on page \(suggestion.pageIndex + 1)."
        return true
    }

    @discardableResult
    func acceptHighConfidenceSuggestions(profile: SignerProfile? = nil, defaultSignatureAssetID: UUID? = nil, defaultInitialsAssetID: UUID? = nil) -> Int {
        let acceptedSuggestions = fieldSuggestions.filter { $0.confidence == .high }
        guard !acceptedSuggestions.isEmpty else {
            statusMessage = "No high-confidence smart suggestions to accept."
            return 0
        }

        let acceptedIDs = Set(acceptedSuggestions.map(\.id))
        let acceptedFields = acceptedSuggestions.map { suggestion in
            makeField(
                kind: suggestion.kind,
                pageIndex: suggestion.pageIndex,
                rect: suggestion.rectInPageSpace,
                profile: profile,
                defaultSignatureAssetID: defaultSignatureAssetID,
                defaultInitialsAssetID: defaultInitialsAssetID
            )
        }

        fieldSuggestions.removeAll { acceptedIDs.contains($0.id) }
        applyFields(fields + acceptedFields, recordUndo: true)
        selectedFieldID = acceptedFields.last?.id
        activeTool = .select
        statusMessage = "Accepted \(acceptedFields.count) high-confidence smart suggestions."
        return acceptedFields.count
    }

    func nearestSuggestion(kind: PlacedField.Kind, pageIndex: Int, point: CGPoint) -> DetectedFieldSuggestion? {
        let compatibleSuggestions = fieldSuggestions.filter {
            $0.kind == kind && $0.pageIndex == pageIndex
        }
        guard !compatibleSuggestions.isEmpty else { return nil }

        let threshold: CGFloat = kind == .checkbox ? 18 : 44
        return compatibleSuggestions
            .map { suggestion in
                (suggestion, suggestion.rectInPageSpace.center.distance(to: point))
            }
            .filter { _, distance in distance <= threshold }
            .min { lhs, rhs in lhs.1 < rhs.1 }?
            .0
    }

    private func defaultRect(for kind: PlacedField.Kind, at point: CGPoint, size: CGSize, pageBounds: CGRect) -> CGRect {
        switch kind {
        case .signature:
            return CGRect(x: point.x - size.width / 2, y: point.y - size.height * 0.22, width: size.width, height: size.height)
                .clamped(to: pageBounds)
                .snapped(to: 2)
        case .initials:
            return CGRect(x: point.x - size.width / 2, y: point.y - size.height * 0.24, width: size.width, height: size.height)
                .clamped(to: pageBounds)
                .snapped(to: 2)
        case .text, .date, .checkbox:
            return CGRect(origin: .zero, size: size)
                .centered(on: point, clampedTo: pageBounds)
                .snapped(to: 2)
        }
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

    func resizeSelectedField(width: CGFloat? = nil, height: CGFloat? = nil) {
        guard
            let selectedFieldID,
            let index = fields.firstIndex(where: { $0.id == selectedFieldID }),
            let pageBounds = pageBounds(for: fields[index].pageIndex)
        else { return }

        var updated = fields
        let minimumSize = updated[index].kind.minimumSize
        if let width {
            updated[index].rectInPageSpace.size.width = max(width, minimumSize.width)
        }
        if let height {
            updated[index].rectInPageSpace.size.height = max(height, minimumSize.height)
        }
        updated[index].rectInPageSpace = updated[index].rectInPageSpace.clamped(to: pageBounds).snapped(to: 2)
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
        exportReceipt = ExportReceipt(url: outputURL)
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

    private func makeField(kind: PlacedField.Kind, pageIndex: Int, rect: CGRect, profile: SignerProfile?, defaultSignatureAssetID: UUID?, defaultInitialsAssetID: UUID?) -> PlacedField {
        PlacedField(
            kind: kind,
            pageIndex: pageIndex,
            rectInPageSpace: rect,
            text: defaultText(for: kind, profile: profile),
            style: defaultStyle(for: kind),
            signatureAssetID: assetID(for: kind, signatureID: defaultSignatureAssetID, initialsID: defaultInitialsAssetID)
        )
    }

    private func openStatusMessage(for statusName: String, suggestionCount: Int) -> String {
        if suggestionCount == 0 {
            return "Opened \(statusName). Add a signature, date, text, or checkbox."
        }

        let noun = suggestionCount == 1 ? "smart field" : "smart fields"
        return "Opened \(statusName). Found \(suggestionCount) likely \(noun) to review."
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

    private func pageBounds(for pageIndex: Int) -> CGRect? {
        document?.page(at: pageIndex)?.bounds(for: .cropBox)
    }

    static func formattedDate(using dateFormat: String?) -> String {
        let formatter = DateFormatter()
        formatter.locale = .current
        formatter.dateFormat = (dateFormat?.isEmpty == false) ? dateFormat : "MMM d, yyyy"
        return formatter.string(from: Date())
    }
}
