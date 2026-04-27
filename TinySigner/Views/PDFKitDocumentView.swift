import AppKit
import PDFKit
import SwiftUI

struct PDFKitDocumentView: NSViewRepresentable {
    @ObservedObject var editor: PDFEditorStore
    var profile: SignerProfile?
    var signatureAssets: [SignatureAsset]

    func makeNSView(context: Context) -> PDFKitDocumentContainerView {
        let view = PDFKitDocumentContainerView()
        view.pdfView.onSelectField = { id in
            editor.selectedFieldID = id
        }
        view.pdfView.onBeginDragField = {
            editor.beginFieldDrag()
        }
        view.pdfView.onFinishDragField = {
            editor.finishFieldDrag()
        }
        view.pdfView.onDeleteSelectedField = {
            editor.deleteSelectedField()
        }
        view.pdfView.onPageChange = { pageIndex in
            editor.currentPageIndex = pageIndex
        }
        return view
    }

    func updateNSView(_ nsView: PDFKitDocumentContainerView, context: Context) {
        let defaultSignatureID = profile?.defaultSignatureAssetID ?? signatureAssets.first(where: { $0.kind != .initials })?.id
        let defaultInitialsID = profile?.defaultInitialsAssetID ?? signatureAssets.first(where: { $0.kind == .initials })?.id
        let assetsByID = Dictionary(uniqueKeysWithValues: signatureAssets.compactMap { asset -> (UUID, Data)? in
            guard let imageData = asset.imageData else { return nil }
            return (asset.id, imageData)
        })

        nsView.pdfView.onCreateField = { tool, pageIndex, point, pageBounds in
            guard let kind = tool.fieldKind else { return }
            editor.addField(
                kind: kind,
                pageIndex: pageIndex,
                at: point,
                pageBounds: pageBounds,
                profile: profile,
                defaultSignatureAssetID: defaultSignatureID,
                defaultInitialsAssetID: defaultInitialsID
            )
        }
        nsView.pdfView.onMoveField = { id, rect, pageBounds in
            editor.updateFieldRect(id: id, rect: rect, pageBounds: pageBounds, recordUndo: false)
        }

        nsView.configure(
            document: editor.document,
            fields: editor.fields,
            selectedFieldID: editor.selectedFieldID,
            activeTool: editor.activeTool,
            zoomScale: editor.zoomScale,
            signatureAssetsByID: assetsByID,
            refreshToken: editor.refreshToken
        )
    }
}

final class PDFKitDocumentContainerView: NSView {
    let pdfView = SigningPDFView()
    private let thumbnailView = PDFThumbnailView()
    private let splitView = NSSplitView()
    private var currentDocument: PDFDocument?
    private var lastRefreshToken = UUID()

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        setupViews()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupViews()
    }

    func configure(
        document: PDFDocument?,
        fields: [PlacedField],
        selectedFieldID: UUID?,
        activeTool: SigningTool,
        zoomScale: CGFloat,
        signatureAssetsByID: [UUID: Data],
        refreshToken: UUID
    ) {
        if currentDocument !== document {
            currentDocument = document
            pdfView.document = document
            thumbnailView.pdfView = pdfView
            pdfView.goToFirstPage(nil)
        }

        pdfView.activeTool = activeTool
        pdfView.fields = fields
        pdfView.selectedFieldID = selectedFieldID
        pdfView.signatureAssetsByID = signatureAssetsByID
        pdfView.minScaleFactor = 0.35
        pdfView.maxScaleFactor = 3.0
        if abs(pdfView.scaleFactor - zoomScale) > 0.01 {
            pdfView.autoScales = false
            pdfView.scaleFactor = zoomScale
        }

        if lastRefreshToken != refreshToken {
            lastRefreshToken = refreshToken
            pdfView.refreshSigningAnnotations()
        }
    }

    private func setupViews() {
        splitView.isVertical = true
        splitView.dividerStyle = .thin
        splitView.translatesAutoresizingMaskIntoConstraints = false

        thumbnailView.translatesAutoresizingMaskIntoConstraints = false
        thumbnailView.thumbnailSize = NSSize(width: 60, height: 84)
        thumbnailView.backgroundColor = .clear

        pdfView.translatesAutoresizingMaskIntoConstraints = false
        pdfView.displayMode = .singlePageContinuous
        pdfView.displayDirection = .vertical
        pdfView.displaysPageBreaks = true
        pdfView.autoScales = false
        pdfView.scaleFactor = 1.0
        pdfView.backgroundColor = NSColor.windowBackgroundColor

        splitView.addArrangedSubview(thumbnailView)
        splitView.addArrangedSubview(pdfView)
        addSubview(splitView)

        NSLayoutConstraint.activate([
            splitView.leadingAnchor.constraint(equalTo: leadingAnchor),
            splitView.trailingAnchor.constraint(equalTo: trailingAnchor),
            splitView.topAnchor.constraint(equalTo: topAnchor),
            splitView.bottomAnchor.constraint(equalTo: bottomAnchor),
            thumbnailView.widthAnchor.constraint(equalToConstant: 104)
        ])
    }
}

final class SigningPDFView: PDFView {
    var activeTool: SigningTool = .select
    var fields: [PlacedField] = []
    var selectedFieldID: UUID?
    var signatureAssetsByID: [UUID: Data] = [:]

    var onCreateField: ((SigningTool, Int, CGPoint, CGRect) -> Void)?
    var onSelectField: ((UUID?) -> Void)?
    var onMoveField: ((UUID, CGRect, CGRect) -> Void)?
    var onBeginDragField: (() -> Void)?
    var onFinishDragField: (() -> Void)?
    var onDeleteSelectedField: (() -> Void)?
    var onPageChange: ((Int) -> Void)?

    private struct DragState {
        var fieldID: UUID
        var pageIndex: Int
        var lastPoint: CGPoint
    }

    private var dragState: DragState?

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        setupNotifications()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupNotifications()
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }

    func refreshSigningAnnotations() {
        guard let document else { return }
        PDFDocumentService.removeTinySignerPreviewAnnotations(from: document)

        for field in fields {
            guard let page = document.page(at: field.pageIndex) else { continue }
            let annotation = SigningFieldAnnotation(
                field: field,
                assetImageData: field.signatureAssetID.flatMap { signatureAssetsByID[$0] },
                selected: field.id == selectedFieldID
            )
            page.addAnnotation(annotation)
        }
        setNeedsDisplay(bounds)
    }

    override func mouseDown(with event: NSEvent) {
        window?.makeFirstResponder(self)
        let viewPoint = convert(event.locationInWindow, from: nil)
        guard let page = page(for: viewPoint, nearest: true), let document else {
            super.mouseDown(with: event)
            return
        }

        let pageIndex = document.index(for: page)
        let pagePoint = convert(viewPoint, to: page)
        let pageBounds = page.bounds(for: .mediaBox)

        if activeTool != .select {
            onCreateField?(activeTool, pageIndex, pagePoint, pageBounds)
            return
        }

        if let hitField = hitField(onPage: pageIndex, at: pagePoint) {
            onSelectField?(hitField.id)
            selectedFieldID = hitField.id
            dragState = DragState(fieldID: hitField.id, pageIndex: pageIndex, lastPoint: pagePoint)
            onBeginDragField?()
            return
        }

        onSelectField?(nil)
        selectedFieldID = nil
        super.mouseDown(with: event)
    }

    override func mouseDragged(with event: NSEvent) {
        guard let dragState, let page = document?.page(at: dragState.pageIndex), let fieldIndex = fields.firstIndex(where: { $0.id == dragState.fieldID }) else {
            super.mouseDragged(with: event)
            return
        }

        let viewPoint = convert(event.locationInWindow, from: nil)
        let pagePoint = convert(viewPoint, to: page)
        let delta = CGPoint(x: pagePoint.x - dragState.lastPoint.x, y: pagePoint.y - dragState.lastPoint.y)
        let pageBounds = page.bounds(for: .mediaBox)
        let movedRect = fields[fieldIndex].rectInPageSpace.offsetBy(dx: delta.x, dy: delta.y).clamped(to: pageBounds)

        fields[fieldIndex].rectInPageSpace = movedRect
        self.dragState = DragState(fieldID: dragState.fieldID, pageIndex: dragState.pageIndex, lastPoint: pagePoint)
        onMoveField?(dragState.fieldID, movedRect, pageBounds)
        refreshSigningAnnotations()
    }

    override func mouseUp(with event: NSEvent) {
        if dragState != nil {
            dragState = nil
            onFinishDragField?()
            return
        }
        super.mouseUp(with: event)
    }

    override func keyDown(with event: NSEvent) {
        if event.keyCode == 51 || event.keyCode == 117 {
            onDeleteSelectedField?()
            return
        }
        super.keyDown(with: event)
    }

    override var acceptsFirstResponder: Bool { true }

    private func hitField(onPage pageIndex: Int, at point: CGPoint) -> PlacedField? {
        fields.reversed().first { field in
            field.pageIndex == pageIndex && field.rectInPageSpace.insetBy(dx: -6, dy: -6).contains(point)
        }
    }

    private func setupNotifications() {
        NotificationCenter.default.addObserver(self, selector: #selector(pageDidChange), name: .PDFViewPageChanged, object: self)
    }

    @objc private func pageDidChange() {
        guard let page = currentPage, let document else { return }
        onPageChange?(document.index(for: page))
    }
}

final class SigningFieldAnnotation: PDFAnnotation {
    static let contentsPrefix = "TinySignerField:"

    private let field: PlacedField
    private let assetImageData: Data?
    private let isSelected: Bool

    init(field: PlacedField, assetImageData: Data?, selected: Bool) {
        self.field = field
        self.assetImageData = assetImageData
        self.isSelected = selected
        super.init(bounds: field.rectInPageSpace, forType: .stamp, withProperties: nil)
        contents = Self.contentsPrefix + field.id.uuidString
    }

    required init?(coder: NSCoder) {
        fatalError("SigningFieldAnnotation is preview-only and is not decoded from PDFs.")
    }

    override func draw(with box: PDFDisplayBox, in context: CGContext) {
        SigningFieldRenderer.draw(field: field, in: context, assetImageData: assetImageData, selected: isSelected)
    }
}
