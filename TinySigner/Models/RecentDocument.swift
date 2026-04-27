import Foundation
import SwiftData

@Model
final class RecentDocument {
    @Attribute(.unique) var id: UUID
    var displayName: String
    var originalPath: String
    var pageCount: Int
    @Attribute(.externalStorage) var bookmarkData: Data
    var lastOpenedAt: Date

    init(
        id: UUID = UUID(),
        displayName: String,
        originalPath: String,
        pageCount: Int,
        bookmarkData: Data,
        lastOpenedAt: Date = Date()
    ) {
        self.id = id
        self.displayName = displayName
        self.originalPath = originalPath
        self.pageCount = pageCount
        self.bookmarkData = bookmarkData
        self.lastOpenedAt = lastOpenedAt
    }
}
