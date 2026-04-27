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
    private var lastPreviewRenderState: PreviewRenderState?

    private struct PreviewRenderState: Equatable {
        var fields: [PlacedField]
        var selectedFieldID: UUID?
        var signatureAssetsByID: [UUID: Data]
        var refreshToken: UUID
    }

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
            if let currentDocument {
                PDFDocumentService.removeTinySignerPreviewAnnotations(from: currentDocument)
            }
            if let document {
                PDFDocumentService.removeTinySignerPreviewAnnotations(from: document)
            }
            currentDocument = document
            pdfView.document = document
            thumbnailView.pdfView = pdfView
            pdfView.goToFirstPage(nil)
            lastPreviewRenderState = nil
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

        let previewRenderState = PreviewRenderState(
            fields: fields,
            selectedFieldID: selectedFieldID,
            signatureAssetsByID: signatureAssetsByID,
            refreshToken: refreshToken
        )
        if lastPreviewRenderState != previewRenderState {
            lastPreviewRenderState = previewRenderState
            pdfView.refreshSigningOverlay()
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

final class SigningOverlayView: NSView {
    weak var pdfView: PDFView?

    private var fields: [PlacedField] = []
    private var selectedFieldID: UUID?
    private var signatureAssetsByID: [UUID: Data] = [:]

    override var isOpaque: Bool { false }

    override func hitTest(_ point: NSPoint) -> NSView? {
        nil
    }

    func configure(fields: [PlacedField], selectedFieldID: UUID?, signatureAssetsByID: [UUID: Data]) {
        self.fields = fields
        self.selectedFieldID = selectedFieldID
        self.signatureAssetsByID = signatureAssetsByID
        needsDisplay = true
    }

    override func draw(_ dirtyRect: NSRect) {
        guard
            let context = NSGraphicsContext.current?.cgContext,
            let pdfView,
            let document = pdfView.document
        else { return }

        for field in fields {
            guard let page = document.page(at: field.pageIndex) else { continue }
            let viewRect = pdfView.convertPageRectToView(field.rectInPageSpace, from: page)
            guard viewRect.intersects(dirtyRect) else { continue }

            SigningFieldRenderer.draw(
                field: field,
                rect: viewRect,
                in: context,
                assetImageData: field.signatureAssetID.flatMap { signatureAssetsByID[$0] },
                selected: field.id == selectedFieldID
            )
        }
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

    private enum InteractionState {
        case move(MoveState)
        case resize(ResizeState)
    }

    private struct MoveState {
        var fieldID: UUID
        var pageIndex: Int
        var lastPoint: CGPoint
    }

    private struct ResizeState {
        var fieldID: UUID
        var pageIndex: Int
        var startRect: CGRect
    }

    private var interactionState: InteractionState?
    private let overlayView = SigningOverlayView()

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        setupOverlay()
        setupNotifications()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupOverlay()
        setupNotifications()
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }

    func refreshSigningOverlay() {
        overlayView.configure(fields: fields, selectedFieldID: selectedFieldID, signatureAssetsByID: signatureAssetsByID)
        overlayView.needsDisplay = true
    }

    override func layout() {
        super.layout()
        overlayView.frame = bounds
        addSubview(overlayView, positioned: .above, relativeTo: nil)
        overlayView.needsDisplay = true
    }

    override func mouseDown(with event: NSEvent) {
        window?.makeFirstResponder(self)
        let viewPoint = convert(event.locationInWindow, from: nil)
        guard let page = page(for: viewPoint, nearest: false), let document else {
            super.mouseDown(with: event)
            return
        }

        let pageIndex = document.index(for: page)
        let pagePoint = convert(viewPoint, to: page)
        let pageBounds = page.bounds(for: displayBox)

        if activeTool != .select {
            onCreateField?(activeTool, pageIndex, pagePoint, pageBounds)
            return
        }

        if let hitField = hitField(onPage: pageIndex, at: pagePoint) {
            onSelectField?(hitField.id)
            selectedFieldID = hitField.id
            if isResizeHandleHit(for: hitField, at: pagePoint) {
                interactionState = .resize(ResizeState(fieldID: hitField.id, pageIndex: pageIndex, startRect: hitField.rectInPageSpace))
            } else {
                interactionState = .move(MoveState(fieldID: hitField.id, pageIndex: pageIndex, lastPoint: pagePoint))
            }
            onBeginDragField?()
            return
        }

        onSelectField?(nil)
        selectedFieldID = nil
        super.mouseDown(with: event)
    }

    override func mouseDragged(with event: NSEvent) {
        guard let interactionState else {
            super.mouseDragged(with: event)
            return
        }

        switch interactionState {
        case .move(let moveState):
            moveField(with: moveState, event: event)
        case .resize(let resizeState):
            resizeField(with: resizeState, event: event)
        }
    }

    private func moveField(with moveState: MoveState, event: NSEvent) {
        guard let page = document?.page(at: moveState.pageIndex), let fieldIndex = fields.firstIndex(where: { $0.id == moveState.fieldID }) else { return }

        let viewPoint = convert(event.locationInWindow, from: nil)
        let pagePoint = convert(viewPoint, to: page)
        let delta = CGPoint(x: pagePoint.x - moveState.lastPoint.x, y: pagePoint.y - moveState.lastPoint.y)
        let pageBounds = page.bounds(for: displayBox)
        let movedRect = fields[fieldIndex].rectInPageSpace.offsetBy(dx: delta.x, dy: delta.y).clamped(to: pageBounds)

        fields[fieldIndex].rectInPageSpace = movedRect
        interactionState = .move(MoveState(fieldID: moveState.fieldID, pageIndex: moveState.pageIndex, lastPoint: pagePoint))
        onMoveField?(moveState.fieldID, movedRect, pageBounds)
        refreshSigningOverlay()
    }

    private func resizeField(with resizeState: ResizeState, event: NSEvent) {
        guard let page = document?.page(at: resizeState.pageIndex), let fieldIndex = fields.firstIndex(where: { $0.id == resizeState.fieldID }) else { return }

        let viewPoint = convert(event.locationInWindow, from: nil)
        let pagePoint = convert(viewPoint, to: page)
        let pageBounds = page.bounds(for: displayBox)
        let minimumSize = fields[fieldIndex].kind.minimumSize
        let resizedRect = resizeState.startRect.resizedFromBottomRight(to: pagePoint, minimumSize: minimumSize, clampedTo: pageBounds)

        fields[fieldIndex].rectInPageSpace = resizedRect
        onMoveField?(resizeState.fieldID, resizedRect, pageBounds)
        refreshSigningOverlay()
    }

    override func mouseUp(with event: NSEvent) {
        if interactionState != nil {
            interactionState = nil
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

    override func scrollWheel(with event: NSEvent) {
        super.scrollWheel(with: event)
        overlayView.needsDisplay = true
    }

    override var acceptsFirstResponder: Bool { true }

    private func hitField(onPage pageIndex: Int, at point: CGPoint) -> PlacedField? {
        fields.reversed().first { field in
            field.pageIndex == pageIndex && field.rectInPageSpace.insetBy(dx: -6, dy: -6).contains(point)
        }
    }

    private func isResizeHandleHit(for field: PlacedField, at point: CGPoint) -> Bool {
        SigningFieldRenderer.resizeHandleRect(for: field.rectInPageSpace)
            .insetBy(dx: -6, dy: -6)
            .contains(point)
    }

    private func setupNotifications() {
        NotificationCenter.default.addObserver(self, selector: #selector(pageDidChange), name: .PDFViewPageChanged, object: self)
        NotificationCenter.default.addObserver(self, selector: #selector(pdfViewGeometryDidChange), name: .PDFViewScaleChanged, object: self)
        NotificationCenter.default.addObserver(self, selector: #selector(pdfViewGeometryDidChange), name: .PDFViewVisiblePagesChanged, object: self)
    }

    @objc private func pageDidChange() {
        guard let page = currentPage, let document else { return }
        onPageChange?(document.index(for: page))
        overlayView.needsDisplay = true
    }

    @objc private func pdfViewGeometryDidChange() {
        overlayView.needsDisplay = true
    }

    private func setupOverlay() {
        overlayView.pdfView = self
        overlayView.frame = bounds
        overlayView.autoresizingMask = [.width, .height]
        overlayView.wantsLayer = true
        overlayView.layer?.backgroundColor = NSColor.clear.cgColor
        addSubview(overlayView, positioned: .above, relativeTo: nil)
    }
}

private extension PDFView {
    func convertPageRectToView(_ rect: CGRect, from page: PDFPage) -> CGRect {
        let origin = convert(rect.origin, from: page)
        let opposite = convert(CGPoint(x: rect.maxX, y: rect.maxY), from: page)
        return CGRect(
            x: min(origin.x, opposite.x),
            y: min(origin.y, opposite.y),
            width: abs(opposite.x - origin.x),
            height: abs(opposite.y - origin.y)
        )
    }
}
