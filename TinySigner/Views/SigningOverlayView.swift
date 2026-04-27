import AppKit
import PDFKit

final class SigningOverlayView: NSView {
    weak var pdfView: PDFView?

    private var fields: [PlacedField] = []
    private var fieldSuggestions: [DetectedFieldSuggestion] = []
    private var selectedFieldID: UUID?
    private var signatureAssetsByID: [UUID: Data] = [:]

    override var isOpaque: Bool { false }

    override func hitTest(_ point: NSPoint) -> NSView? {
        nil
    }

    func configure(fields: [PlacedField], fieldSuggestions: [DetectedFieldSuggestion], selectedFieldID: UUID?, signatureAssetsByID: [UUID: Data]) {
        self.fields = fields
        self.fieldSuggestions = fieldSuggestions
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

        for suggestion in fieldSuggestions {
            guard let page = document.page(at: suggestion.pageIndex) else { continue }
            let viewRect = pdfView.convertPageRectToView(suggestion.rectInPageSpace, from: page)
            guard viewRect.insetBy(dx: -28, dy: -20).intersects(dirtyRect) else { continue }
            drawSuggestion(suggestion, rect: viewRect, in: context)
        }

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

    private func drawSuggestion(_ suggestion: DetectedFieldSuggestion, rect: CGRect, in context: CGContext) {
        let color = suggestion.confidence.strokeColor
        context.saveGState()
        context.setStrokeColor(color.withAlphaComponent(0.70).cgColor)
        context.setFillColor(color.withAlphaComponent(0.08).cgColor)
        context.setLineWidth(1.3)
        context.setLineDash(phase: 0, lengths: [6, 4])

        let path = CGPath(roundedRect: rect, cornerWidth: 7, cornerHeight: 7, transform: nil)
        context.addPath(path)
        context.drawPath(using: .fillStroke)
        context.restoreGState()

        let badge = "\(suggestion.kind.title) · \(suggestion.confidence.title)"
        let attributes: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: 10, weight: .semibold),
            .foregroundColor: color
        ]
        let attributed = NSAttributedString(string: badge, attributes: attributes)
        let size = attributed.size()
        let badgeRect = CGRect(
            x: rect.minX,
            y: max(0, rect.minY - size.height - 5),
            width: size.width + 12,
            height: size.height + 5
        )
        NSColor.controlBackgroundColor.withAlphaComponent(0.88).setFill()
        NSBezierPath(roundedRect: badgeRect, xRadius: 5, yRadius: 5).fill()
        attributed.draw(at: CGPoint(x: badgeRect.minX + 6, y: badgeRect.minY + 2))
    }
}

private extension DetectionConfidence {
    var strokeColor: NSColor {
        switch self {
        case .high: .systemBlue
        case .medium: .systemTeal
        case .low: .systemGray
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
