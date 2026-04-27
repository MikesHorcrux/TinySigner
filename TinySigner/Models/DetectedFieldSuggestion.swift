import CoreGraphics
import Foundation

enum DetectionConfidence: String, Codable, CaseIterable {
    case high
    case medium
    case low

    var title: String {
        switch self {
        case .high: "High"
        case .medium: "Medium"
        case .low: "Low"
        }
    }
}

struct DetectedFieldSuggestion: Identifiable, Codable, Equatable {
    var id: UUID
    var kind: PlacedField.Kind
    var pageIndex: Int
    var rectInPageSpace: CGRect
    var sourceLabel: String
    var confidence: DetectionConfidence

    init(
        id: UUID = UUID(),
        kind: PlacedField.Kind,
        pageIndex: Int,
        rectInPageSpace: CGRect,
        sourceLabel: String,
        confidence: DetectionConfidence
    ) {
        self.id = id
        self.kind = kind
        self.pageIndex = pageIndex
        self.rectInPageSpace = rectInPageSpace
        self.sourceLabel = sourceLabel
        self.confidence = confidence
    }
}

extension CGRect {
    var center: CGPoint { CGPoint(x: midX, y: midY) }
}

extension CGPoint {
    func distance(to other: CGPoint) -> CGFloat {
        hypot(x - other.x, y - other.y)
    }
}
