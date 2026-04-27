import Foundation

/// Tools exposed in the editor. `select` edits existing fields; the rest create fields.
enum SigningTool: String, CaseIterable, Identifiable, Codable {
    case select
    case signature
    case initials
    case text
    case date
    case checkbox

    var id: String { rawValue }

    var title: String {
        switch self {
        case .select: "Select"
        case .signature: "Signature"
        case .initials: "Initials"
        case .text: "Text"
        case .date: "Date"
        case .checkbox: "Check"
        }
    }

    var systemImage: String {
        switch self {
        case .select: "cursorarrow"
        case .signature: "signature"
        case .initials: "textformat.size.smaller"
        case .text: "text.cursor"
        case .date: "calendar"
        case .checkbox: "checkmark.square"
        }
    }

    var fieldKind: PlacedField.Kind? {
        switch self {
        case .select: nil
        case .signature: .signature
        case .initials: .initials
        case .text: .text
        case .date: .date
        case .checkbox: .checkbox
        }
    }
}
