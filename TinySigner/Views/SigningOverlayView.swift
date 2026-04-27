import AppKit
import PDFKit

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
