import AppKit
import Foundation
import PDFKit
import UniformTypeIdentifiers

struct PDFDocumentService {
    enum ServiceError: LocalizedError {
        case cannotOpenPDF
        case missingDocument
        case cannotCreateOutput
        case cannotResolveBookmark

        var errorDescription: String? {
            switch self {
            case .cannotOpenPDF: "TinySigner could not open that PDF."
            case .missingDocument: "Open a PDF before exporting."
            case .cannotCreateOutput: "TinySigner could not create the signed PDF."
            case .cannotResolveBookmark: "TinySigner could not reopen that recent document."
            }
        }
    }

    func openDocument(from url: URL) throws -> PDFDocument {
        guard let document = PDFDocument(url: url) else {
            throw ServiceError.cannotOpenPDF
        }
        return document
    }

    func makeDemoDocument(title: String = "TinySigner Fixture") -> PDFDocument {
        let pageSize = CGSize(width: 612, height: 792)
        let image = NSImage(size: pageSize)
        image.lockFocus()
        NSColor.white.setFill()
        NSRect(origin: .zero, size: pageSize).fill()
        let attributed = NSAttributedString(
            string: title,
            attributes: [
                .font: NSFont.systemFont(ofSize: 28, weight: .semibold),
                .foregroundColor: NSColor.black
            ]
        )
        attributed.draw(in: CGRect(x: 72, y: 690, width: 420, height: 48))
        image.unlockFocus()

        let document = PDFDocument()
        if let page = PDFPage(image: image) {
            document.insert(page, at: 0)
        }
        return document
    }

    func makeSecurityScopedBookmark(for url: URL) throws -> Data {
        try url.bookmarkData(options: [.withSecurityScope], includingResourceValuesForKeys: nil, relativeTo: nil)
    }

    func resolveSecurityScopedBookmark(_ data: Data) throws -> URL {
        var isStale = false
        let url = try URL(resolvingBookmarkData: data, options: [.withSecurityScope], relativeTo: nil, bookmarkDataIsStale: &isStale)
        guard !isStale else { throw ServiceError.cannotResolveBookmark }
        return url
    }

    func defaultSignedFilename(for originalURL: URL?) -> String {
        guard let originalURL else { return "signed.pdf" }
        let baseName = originalURL.deletingPathExtension().lastPathComponent
        return "\(baseName)-signed.pdf"
    }

    func exportFlattenedPDF(document: PDFDocument, fields: [PlacedField], signatureAssetsByID: [UUID: Data], to outputURL: URL) throws {
        guard document.pageCount > 0 else { throw ServiceError.missingDocument }
        Self.removeTinySignerPreviewAnnotations(from: document)

        guard let consumer = CGDataConsumer(url: outputURL as CFURL) else {
            throw ServiceError.cannotCreateOutput
        }

        var firstPageBox = document.page(at: 0)?.bounds(for: .mediaBox) ?? CGRect(x: 0, y: 0, width: 612, height: 792)
        guard let context = CGContext(consumer: consumer, mediaBox: &firstPageBox, nil) else {
            throw ServiceError.cannotCreateOutput
        }

        for pageIndex in 0..<document.pageCount {
            guard let page = document.page(at: pageIndex) else { continue }
            let pageBox = page.bounds(for: .mediaBox)
            context.beginPDFPage([kCGPDFContextMediaBox as String: pageBox] as CFDictionary)
            page.draw(with: .mediaBox, to: context)

            for field in fields where field.pageIndex == pageIndex {
                SigningFieldRenderer.draw(
                    field: field,
                    in: context,
                    assetImageData: field.signatureAssetID.flatMap { signatureAssetsByID[$0] }
                )
            }

            context.endPDFPage()
        }

        context.closePDF()
    }

    static func removeTinySignerPreviewAnnotations(from document: PDFDocument) {
        for pageIndex in 0..<document.pageCount {
            guard let page = document.page(at: pageIndex) else { continue }
            for annotation in page.annotations where annotation is SigningFieldAnnotation || annotation.contents?.hasPrefix(SigningFieldAnnotation.contentsPrefix) == true {
                page.removeAnnotation(annotation)
            }
        }
    }
}
