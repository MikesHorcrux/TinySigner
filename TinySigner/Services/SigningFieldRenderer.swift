import AppKit
import CoreGraphics
import PDFKit

struct SigningFieldRenderer {
    static func draw(field: PlacedField, in context: CGContext, assetImageData: Data?, selected: Bool = false) {
        let rect = field.rectInPageSpace
        context.saveGState()

        if selected {
            drawSelection(for: rect, in: context)
        }

        switch field.kind {
        case .checkbox:
            drawCheckbox(field: field, in: context)
        case .signature, .initials:
            if let assetImageData, drawImage(assetImageData, in: rect, context: context) {
                break
            }
            drawText(field.text.isEmpty ? field.kind.title : field.text, field: field, in: context, signatureStyle: true)
        case .text, .date:
            drawText(field.text, field: field, in: context, signatureStyle: false)
        }

        context.restoreGState()
    }

    private static func drawSelection(for rect: CGRect, in context: CGContext) {
        context.setFillColor(NSColor.controlAccentColor.withAlphaComponent(0.12).cgColor)
        context.fill(rect)
        context.setStrokeColor(NSColor.controlAccentColor.cgColor)
        context.setLineWidth(1)
        context.setLineDash(phase: 0, lengths: [5, 3])
        context.stroke(rect.insetBy(dx: 0.5, dy: 0.5))
        context.setLineDash(phase: 0, lengths: [])
    }

    private static func drawCheckbox(field: PlacedField, in context: CGContext) {
        let rect = field.rectInPageSpace.insetBy(dx: 2, dy: 2)
        context.setStrokeColor(field.style.cgColor)
        context.setLineWidth(field.style.lineWidth)
        context.stroke(rect)

        guard field.text.lowercased() != "off" else { return }
        let start = CGPoint(x: rect.minX + rect.width * 0.20, y: rect.midY)
        let middle = CGPoint(x: rect.minX + rect.width * 0.42, y: rect.minY + rect.height * 0.25)
        let end = CGPoint(x: rect.maxX - rect.width * 0.15, y: rect.maxY - rect.height * 0.18)
        context.move(to: start)
        context.addLine(to: middle)
        context.addLine(to: end)
        context.strokePath()
    }

    @discardableResult
    private static func drawImage(_ data: Data, in rect: CGRect, context: CGContext) -> Bool {
        guard let image = NSImage(data: data), let cgImage = image.cgImage(forProposedRect: nil, context: nil, hints: nil) else {
            return false
        }

        context.saveGState()
        context.interpolationQuality = .high
        context.draw(cgImage, in: rect)
        context.restoreGState()
        return true
    }

    private static func drawText(_ text: String, field: PlacedField, in context: CGContext, signatureStyle: Bool) {
        let rect = field.rectInPageSpace.insetBy(dx: 5, dy: 3)
        let font = font(for: field, signatureStyle: signatureStyle)
        let paragraph = NSMutableParagraphStyle()
        paragraph.alignment = signatureStyle ? .center : .left
        paragraph.lineBreakMode = .byTruncatingTail

        let attributed = NSAttributedString(
            string: text.isEmpty ? " " : text,
            attributes: [
                .font: font,
                .foregroundColor: field.style.nsColor,
                .paragraphStyle: paragraph
            ]
        )
        let textSize = attributed.boundingRect(
            with: CGSize(width: rect.width, height: CGFloat.greatestFiniteMagnitude),
            options: [.usesLineFragmentOrigin, .usesFontLeading]
        ).size
        let drawRect = CGRect(
            x: rect.minX,
            y: rect.midY - min(textSize.height, rect.height) / 2,
            width: rect.width,
            height: max(rect.height, textSize.height)
        )

        NSGraphicsContext.saveGraphicsState()
        let previous = NSGraphicsContext.current
        NSGraphicsContext.current = NSGraphicsContext(cgContext: context, flipped: false)
        attributed.draw(with: drawRect, options: [.usesLineFragmentOrigin, .usesFontLeading])
        NSGraphicsContext.current = previous
        NSGraphicsContext.restoreGraphicsState()
    }

    private static func font(for field: PlacedField, signatureStyle: Bool) -> NSFont {
        let maxSize = max(10, min(field.style.fontSize, field.rectInPageSpace.height * 0.78))
        if signatureStyle {
            return NSFont(name: "Snell Roundhand", size: maxSize) ?? NSFont.systemFont(ofSize: maxSize, weight: .regular)
        }
        return NSFont.systemFont(ofSize: maxSize, weight: .regular)
    }
}

extension FieldStyle {
    var nsColor: NSColor {
        NSColor(calibratedRed: red, green: green, blue: blue, alpha: alpha)
    }

    var cgColor: CGColor {
        nsColor.cgColor
    }
}
