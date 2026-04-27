import AppKit
import SwiftUI

struct SignatureDrawingCanvas: NSViewRepresentable {
    @Binding var strokes: [SignatureStroke]

    func makeNSView(context: Context) -> SignatureDrawingNSView {
        let view = SignatureDrawingNSView()
        view.strokes = strokes
        view.onChange = { strokes = $0 }
        return view
    }

    func updateNSView(_ nsView: SignatureDrawingNSView, context: Context) {
        nsView.strokes = strokes
        nsView.onChange = { strokes = $0 }
        nsView.needsDisplay = true
    }
}

final class SignatureDrawingNSView: NSView {
    var strokes: [SignatureStroke] = []
    var onChange: (([SignatureStroke]) -> Void)?
    private var currentStroke: SignatureStroke?

    override var acceptsFirstResponder: Bool { true }

    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)
        NSColor.textColor.withAlphaComponent(0.86).setStroke()
        drawGuideLine()
        draw(strokes: strokes)
        if let currentStroke {
            draw(strokes: [currentStroke])
        }
    }

    override func mouseDown(with event: NSEvent) {
        window?.makeFirstResponder(self)
        currentStroke = SignatureStroke(points: [convert(event.locationInWindow, from: nil)])
        needsDisplay = true
    }

    override func mouseDragged(with event: NSEvent) {
        currentStroke?.points.append(convert(event.locationInWindow, from: nil))
        needsDisplay = true
    }

    override func mouseUp(with event: NSEvent) {
        guard var currentStroke else { return }
        currentStroke.points.append(convert(event.locationInWindow, from: nil))
        strokes.append(currentStroke)
        self.currentStroke = nil
        onChange?(strokes)
        needsDisplay = true
    }

    private func draw(strokes: [SignatureStroke]) {
        for stroke in strokes where stroke.points.count > 1 {
            let path = NSBezierPath()
            path.lineWidth = 3
            path.lineCapStyle = .round
            path.lineJoinStyle = .round
            path.move(to: stroke.points[0])
            for point in stroke.points.dropFirst() {
                path.line(to: point)
            }
            path.stroke()
        }
    }

    private func drawGuideLine() {
        let guide = NSBezierPath()
        guide.lineWidth = 1
        guide.setLineDash([5, 4], count: 2, phase: 0)
        guide.move(to: CGPoint(x: 16, y: bounds.height * 0.28))
        guide.line(to: CGPoint(x: bounds.width - 16, y: bounds.height * 0.28))
        NSColor.separatorColor.setStroke()
        guide.stroke()
    }
}
