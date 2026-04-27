import Foundation
import SwiftData

@Model
final class SignerProfile {
    @Attribute(.unique) var id: UUID
    var fullName: String
    var initials: String
    var preferredDateFormat: String
    var defaultSignatureAssetID: UUID?
    var defaultInitialsAssetID: UUID?
    var updatedAt: Date

    init(
        id: UUID = UUID(),
        fullName: String = "",
        initials: String = "",
        preferredDateFormat: String = "MMM d, yyyy",
        defaultSignatureAssetID: UUID? = nil,
        defaultInitialsAssetID: UUID? = nil,
        updatedAt: Date = Date()
    ) {
        self.id = id
        self.fullName = fullName
        self.initials = initials
        self.preferredDateFormat = preferredDateFormat
        self.defaultSignatureAssetID = defaultSignatureAssetID
        self.defaultInitialsAssetID = defaultInitialsAssetID
        self.updatedAt = updatedAt
    }
}
