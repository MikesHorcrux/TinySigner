import AppKit
import Foundation

struct SignatureStroke: Identifiable, Codable, Equatable {
    var id: UUID
    var points: [CGPoint]

    init(id: UUID = UUID(), points: [CGPoint]) {
        self.id = id
        self.points = points
    }
}

struct SignatureRenderer {
    static func renderTextSignature(_ text: String, size: CGSize = CGSize(width: 520, height: 150)) -> Data? {
        let displayText = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !displayText.isEmpty else { return nil }

        let image = NSImage(size: size)
        image.lockFocus()
        NSColor.clear.setFill()
        NSRect(origin: .zero, size: size).fill()

        let font = NSFont(name: "Snell Roundhand", size: size.height * 0.52) ?? NSFont.systemFont(ofSize: size.height * 0.42, weight: .regular)
        let paragraph = NSMutableParagraphStyle()
        paragraph.alignment = .center
        let attributed = NSAttributedString(
            string: displayText,
            attributes: [
                .font: font,
                .foregroundColor: NSColor(calibratedRed: 0.02, green: 0.06, blue: 0.12, alpha: 1),
                .paragraphStyle: paragraph
            ]
        )
        let rect = NSRect(x: 10, y: size.height * 0.22, width: size.width - 20, height: size.height * 0.6)
        attributed.draw(with: rect, options: [.usesLineFragmentOrigin, .usesFontLeading])
        image.unlockFocus()

        return image.pngData()
    }

    static func renderStrokes(_ strokes: [SignatureStroke], size: CGSize = CGSize(width: 520, height: 150), lineWidth: CGFloat = 4) -> Data? {
        guard strokes.contains(where: { $0.points.count > 1 }) else { return nil }
        let points = strokes.flatMap(\.points)
        guard let strokeBounds = bounds(containing: points) else { return nil }

        let image = NSImage(size: size)
        image.lockFocus()
        NSColor.clear.setFill()
        NSRect(origin: .zero, size: size).fill()
        NSColor(calibratedRed: 0.02, green: 0.06, blue: 0.12, alpha: 1).setStroke()

        let targetRect = CGRect(
            x: size.width * 0.05,
            y: size.height * 0.14,
            width: size.width * 0.90,
            height: size.height * 0.72
        )
        let transform = normalizedTransform(from: strokeBounds, to: targetRect)

        for stroke in strokes where stroke.points.count > 1 {
            let path = NSBezierPath()
            path.lineCapStyle = .round
            path.lineJoinStyle = .round
            path.lineWidth = lineWidth
            path.move(to: transform(stroke.points[0]))
            for point in stroke.points.dropFirst() {
                path.line(to: transform(point))
            }
            path.stroke()
        }

        image.unlockFocus()
        return image.pngData()
    }

    private static func bounds(containing points: [CGPoint]) -> CGRect? {
        guard let first = points.first else { return nil }
        return points.dropFirst().reduce(CGRect(origin: first, size: .zero)) { partial, point in
            partial.union(CGRect(origin: point, size: .zero))
        }
    }

    private static func normalizedTransform(from source: CGRect, to target: CGRect) -> (CGPoint) -> CGPoint {
        let sourceWidth = max(source.width, 1)
        let sourceHeight = max(source.height, 1)
        let scale = min(target.width / sourceWidth, target.height / sourceHeight)
        let fittedSize = CGSize(width: sourceWidth * scale, height: sourceHeight * scale)
        let origin = CGPoint(
            x: target.midX - fittedSize.width / 2,
            y: target.midY - fittedSize.height / 2
        )

        return { point in
            CGPoint(
                x: origin.x + (point.x - source.minX) * scale,
                y: origin.y + (point.y - source.minY) * scale
            )
        }
    }
}

extension NSImage {
    func pngData() -> Data? {
        guard let tiffRepresentation, let bitmap = NSBitmapImageRep(data: tiffRepresentation) else {
            return nil
        }
        return bitmap.representation(using: .png, properties: [:])
    }
}
