import Foundation
import SwiftData

@Model
final class SignatureAsset {
    enum Kind: String, Codable, CaseIterable, Identifiable {
        case typedSignature
        case drawnSignature
        case importedImage
        case initials

        var id: String { rawValue }

        var title: String {
            switch self {
            case .typedSignature: "Typed Signature"
            case .drawnSignature: "Drawn Signature"
            case .importedImage: "Imported Image"
            case .initials: "Initials"
            }
        }
    }

    @Attribute(.unique) var id: UUID
    var name: String
    var kindRawValue: String
    var typedText: String?
    @Attribute(.externalStorage) var imageData: Data?
    var createdAt: Date
    var updatedAt: Date

    var kind: Kind {
        get { Kind(rawValue: kindRawValue) ?? .typedSignature }
        set { kindRawValue = newValue.rawValue }
    }

    init(
        id: UUID = UUID(),
        name: String,
        kind: Kind,
        typedText: String? = nil,
        imageData: Data? = nil,
        createdAt: Date = Date(),
        updatedAt: Date = Date()
    ) {
        self.id = id
        self.name = name
        self.kindRawValue = kind.rawValue
        self.typedText = typedText
        self.imageData = imageData
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}
