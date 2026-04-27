import CoreGraphics
import Foundation

struct PlacedField: Identifiable, Codable, Equatable {
    enum Kind: String, CaseIterable, Codable, Identifiable {
        case signature
        case initials
        case text
        case date
        case checkbox

        var id: String { rawValue }

        var title: String {
            switch self {
            case .signature: "Signature"
            case .initials: "Initials"
            case .text: "Text"
            case .date: "Date"
            case .checkbox: "Checkbox"
            }
        }

        var defaultSize: CGSize {
            switch self {
            case .signature: CGSize(width: 220, height: 64)
            case .initials: CGSize(width: 96, height: 42)
            case .text: CGSize(width: 190, height: 34)
            case .date: CGSize(width: 138, height: 32)
            case .checkbox: CGSize(width: 24, height: 24)
            }
        }

        var minimumSize: CGSize {
            switch self {
            case .signature: CGSize(width: 96, height: 32)
            case .initials: CGSize(width: 42, height: 24)
            case .text: CGSize(width: 52, height: 24)
            case .date: CGSize(width: 74, height: 24)
            case .checkbox: CGSize(width: 18, height: 18)
            }
        }
    }

    var id: UUID
    var kind: Kind
    var pageIndex: Int
    var rectInPageSpace: CGRect
    var text: String
    var style: FieldStyle
    var signatureAssetID: UUID?

    init(
        id: UUID = UUID(),
        kind: Kind,
        pageIndex: Int,
        rectInPageSpace: CGRect,
        text: String = "",
        style: FieldStyle = .default,
        signatureAssetID: UUID? = nil
    ) {
        self.id = id
        self.kind = kind
        self.pageIndex = pageIndex
        self.rectInPageSpace = rectInPageSpace
        self.text = text
        self.style = style
        self.signatureAssetID = signatureAssetID
    }
}

struct FieldStyle: Codable, Equatable {
    var fontSize: CGFloat
    var red: CGFloat
    var green: CGFloat
    var blue: CGFloat
    var alpha: CGFloat
    var lineWidth: CGFloat

    static let `default` = FieldStyle(fontSize: 18, red: 0.05, green: 0.08, blue: 0.12, alpha: 1, lineWidth: 1.4)
    static let signature = FieldStyle(fontSize: 34, red: 0.02, green: 0.06, blue: 0.12, alpha: 1, lineWidth: 1.6)
    static let checkbox = FieldStyle(fontSize: 16, red: 0.02, green: 0.06, blue: 0.12, alpha: 1, lineWidth: 1.5)
}

extension CGRect {
    func centered(on point: CGPoint, clampedTo bounds: CGRect) -> CGRect {
        let proposed = CGRect(
            x: point.x - width / 2,
            y: point.y - height / 2,
            width: width,
            height: height
        )
        return proposed.clamped(to: bounds)
    }

    func clamped(to bounds: CGRect) -> CGRect {
        let maxX = max(bounds.minX, bounds.maxX - width)
        let maxY = max(bounds.minY, bounds.maxY - height)
        return CGRect(
            x: min(max(origin.x, bounds.minX), maxX),
            y: min(max(origin.y, bounds.minY), maxY),
            width: min(width, bounds.width),
            height: min(height, bounds.height)
        )
    }

    func snapped(to grid: CGFloat) -> CGRect {
        guard grid > 0 else { return self }
        func snap(_ value: CGFloat) -> CGFloat { (value / grid).rounded() * grid }
        return CGRect(x: snap(minX), y: snap(minY), width: snap(width), height: snap(height))
    }

    func resizedFromBottomRight(to point: CGPoint, minimumSize: CGSize, clampedTo bounds: CGRect) -> CGRect {
        let maxWidth = max(minimumSize.width, bounds.maxX - minX)
        let maxHeight = max(minimumSize.height, maxY - bounds.minY)
        let width = min(max(point.x - minX, minimumSize.width), maxWidth)
        let height = min(max(maxY - point.y, minimumSize.height), maxHeight)
        return CGRect(x: minX, y: maxY - height, width: width, height: height).clamped(to: bounds)
    }
}
