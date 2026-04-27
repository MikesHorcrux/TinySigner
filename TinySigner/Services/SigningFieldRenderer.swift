import AppKit
import CoreGraphics
import PDFKit

struct SigningFieldRenderer {
    static func draw(field: PlacedField, in context: CGContext, assetImageData: Data?, selected: Bool = false) {
        draw(field: field, rect: field.rectInPageSpace, in: context, assetImageData: assetImageData, selected: selected)
    }

    static func draw(field: PlacedField, rect: CGRect, in context: CGContext, assetImageData: Data?, selected: Bool = false) {
        context.saveGState()

        switch field.kind {
        case .checkbox:
            drawCheckbox(field: field, rect: rect, in: context)
        case .signature, .initials:
            if let assetImageData, drawImage(assetImageData, in: rect, context: context) {
                break
            }
            drawText(field.text.isEmpty ? field.kind.title : field.text, rect: rect, field: field, in: context, signatureStyle: true)
        case .text, .date:
            drawText(field.text, rect: rect, field: field, in: context, signatureStyle: false)
        }

        if selected {
            drawSelection(for: rect, in: context)
        }

        context.restoreGState()
    }

    private static func drawSelection(for rect: CGRect, in context: CGContext) {
        context.saveGState()
        context.clip(to: rect.insetBy(dx: -8, dy: -8))
        context.setStrokeColor(NSColor.controlAccentColor.cgColor)
        context.setLineWidth(1.25)
        context.setLineDash(phase: 0, lengths: [5, 3])
        context.stroke(rect.insetBy(dx: 0.5, dy: 0.5))
        context.setLineDash(phase: 0, lengths: [])

        let handleRect = resizeHandleRect(for: rect)
        context.setFillColor(NSColor.controlAccentColor.cgColor)
        context.fill(handleRect)
        context.setStrokeColor(NSColor.white.withAlphaComponent(0.95).cgColor)
        context.setLineWidth(1)
        context.stroke(handleRect.insetBy(dx: 0.5, dy: 0.5))
        context.restoreGState()
    }

    private static func drawCheckbox(field: PlacedField, rect: CGRect, in context: CGContext) {
        let rect = rect.insetBy(dx: 2, dy: 2)
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
        guard let image = NSImage(data: data), image.size.width > 0, image.size.height > 0 else {
            return false
        }

        context.saveGState()
        NSGraphicsContext.saveGraphicsState()
        let previous = NSGraphicsContext.current
        let graphicsContext = NSGraphicsContext(cgContext: context, flipped: false)
        graphicsContext.imageInterpolation = .high
        NSGraphicsContext.current = graphicsContext

        let drawRect = aspectFitRect(for: image.size, in: rect.insetBy(dx: 2, dy: 2))
        image.draw(
            in: drawRect,
            from: NSRect(origin: .zero, size: image.size),
            operation: .sourceOver,
            fraction: 1,
            respectFlipped: false,
            hints: [.interpolation: NSImageInterpolation.high]
        )

        NSGraphicsContext.current = previous
        NSGraphicsContext.restoreGraphicsState()
        context.restoreGState()
        return true
    }

    private static func drawText(_ text: String, rect: CGRect, field: PlacedField, in context: CGContext, signatureStyle: Bool) {
        let rect = rect.insetBy(dx: 5, dy: 3)
        let font = font(for: field, rect: rect, signatureStyle: signatureStyle)
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

    private static func font(for field: PlacedField, rect: CGRect, signatureStyle: Bool) -> NSFont {
        let maxSize = max(10, min(field.style.fontSize, rect.height * 0.78))
        if signatureStyle {
            return NSFont(name: "Snell Roundhand", size: maxSize) ?? NSFont.systemFont(ofSize: maxSize, weight: .regular)
        }
        return NSFont.systemFont(ofSize: maxSize, weight: .regular)
    }

    static func resizeHandleRect(for rect: CGRect) -> CGRect {
        let size: CGFloat = 9
        return CGRect(x: rect.maxX - size, y: rect.minY, width: size, height: size)
    }

    private static func aspectFitRect(for imageSize: CGSize, in rect: CGRect) -> CGRect {
        guard imageSize.width > 0, imageSize.height > 0, rect.width > 0, rect.height > 0 else {
            return rect
        }

        let scale = min(rect.width / imageSize.width, rect.height / imageSize.height)
        let size = CGSize(width: imageSize.width * scale, height: imageSize.height * scale)
        return CGRect(
            x: rect.midX - size.width / 2,
            y: rect.midY - size.height / 2,
            width: size.width,
            height: size.height
        )
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
