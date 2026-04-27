import AppKit
import PDFKit

final class SigningPDFView: PDFView {
    var activeTool: SigningTool = .select
    var fields: [PlacedField] = []
    var fieldSuggestions: [DetectedFieldSuggestion] = []
    var selectedFieldID: UUID?
    var signatureAssetsByID: [UUID: Data] = [:]

    var onCreateField: ((SigningTool, Int, CGPoint, CGRect) -> Void)?
    var onSelectField: ((UUID?) -> Void)?
    var onMoveField: ((UUID, CGRect, CGRect) -> Void)?
    var onBeginDragField: (() -> Void)?
    var onFinishDragField: (() -> Void)?
    var onDeleteSelectedField: (() -> Void)?
    var onAcceptSuggestion: ((UUID) -> Void)?
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
        overlayView.configure(fields: fields, fieldSuggestions: fieldSuggestions, selectedFieldID: selectedFieldID, signatureAssetsByID: signatureAssetsByID)
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

        if let hitSuggestion = hitSuggestion(onPage: pageIndex, at: pagePoint) {
            onAcceptSuggestion?(hitSuggestion.id)
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

    private func moveField(with moveState: MoveState, event: NSEvent) {
        guard
            let page = document?.page(at: moveState.pageIndex),
            let fieldIndex = fields.firstIndex(where: { $0.id == moveState.fieldID })
        else { return }

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
        guard
            let page = document?.page(at: resizeState.pageIndex),
            let fieldIndex = fields.firstIndex(where: { $0.id == resizeState.fieldID })
        else { return }

        let viewPoint = convert(event.locationInWindow, from: nil)
        let pagePoint = convert(viewPoint, to: page)
        let pageBounds = page.bounds(for: displayBox)
        let minimumSize = fields[fieldIndex].kind.minimumSize
        let resizedRect = resizeState.startRect.resizedFromBottomRight(to: pagePoint, minimumSize: minimumSize, clampedTo: pageBounds)

        fields[fieldIndex].rectInPageSpace = resizedRect
        onMoveField?(resizeState.fieldID, resizedRect, pageBounds)
        refreshSigningOverlay()
    }

    private func hitField(onPage pageIndex: Int, at point: CGPoint) -> PlacedField? {
        fields.reversed().first { field in
            field.pageIndex == pageIndex && field.rectInPageSpace.insetBy(dx: -6, dy: -6).contains(point)
        }
    }

    private func hitSuggestion(onPage pageIndex: Int, at point: CGPoint) -> DetectedFieldSuggestion? {
        fieldSuggestions
            .filter { $0.pageIndex == pageIndex && $0.rectInPageSpace.insetBy(dx: -8, dy: -8).contains(point) }
            .sorted {
                if $0.confidence != $1.confidence { return $0.confidence.rank > $1.confidence.rank }
                return $0.rectInPageSpace.area < $1.rectInPageSpace.area
            }
            .first
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

private extension DetectionConfidence {
    var rank: Int {
        switch self {
        case .high: 3
        case .medium: 2
        case .low: 1
        }
    }
}

private extension CGRect {
    var area: CGFloat { width * height }
}
