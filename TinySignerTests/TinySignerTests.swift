import CoreGraphics
import Foundation
import PDFKit
import SwiftData
import Testing
@testable import TinySigner

struct SigningModelTests {
    @Test func placedFieldCodableRoundTripPreservesPageRectAndKind() throws {
        let field = PlacedField(
            kind: .signature,
            pageIndex: 1,
            rectInPageSpace: CGRect(x: 32, y: 48, width: 220, height: 64),
            text: "Jane Appleseed",
            style: .signature,
            signatureAssetID: UUID()
        )

        let data = try JSONEncoder().encode(field)
        let decoded = try JSONDecoder().decode(PlacedField.self, from: data)

        #expect(decoded == field)
        #expect(decoded.rectInPageSpace == CGRect(x: 32, y: 48, width: 220, height: 64))
    }

    @Test func defaultSignedFilenameAddsSignedSuffix() {
        let service = PDFDocumentService()
        let url = URL(fileURLWithPath: "/tmp/contract.final.pdf")

        #expect(service.defaultSignedFilename(for: url) == "contract.final-signed.pdf")
        #expect(service.defaultSignedFilename(for: nil) == "signed.pdf")
    }

    @Test func fieldRectClampKeepsFieldInsidePageBounds() {
        let pageBounds = CGRect(x: 0, y: 0, width: 300, height: 400)
        let proposed = CGRect(x: 260, y: 385, width: 80, height: 50)

        #expect(proposed.clamped(to: pageBounds) == CGRect(x: 220, y: 350, width: 80, height: 50))
    }
}

@MainActor
struct PDFExportTests {
    @Test func exportFlattenedPDFCreatesReadableMultiPageCopy() throws {
        let fixtureURL = try PDFTestFactory.makeFixturePDF(pageCount: 2)
        let outputURL = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent("TinySignerExport-\(UUID().uuidString).pdf")
        let service = PDFDocumentService()
        let document = try service.openDocument(from: fixtureURL)
        let fields = [
            PlacedField(kind: .text, pageIndex: 0, rectInPageSpace: CGRect(x: 72, y: 610, width: 180, height: 36), text: "Approved"),
            PlacedField(kind: .checkbox, pageIndex: 1, rectInPageSpace: CGRect(x: 72, y: 560, width: 24, height: 24), text: "on", style: .checkbox)
        ]

        try service.exportFlattenedPDF(document: document, fields: fields, signatureAssetsByID: [:], to: outputURL)

        let exported = PDFDocument(url: outputURL)
        #expect(exported?.pageCount == 2)
        #expect((try FileManager.default.attributesOfItem(atPath: outputURL.path)[.size] as? NSNumber)?.intValue ?? 0 > 0)
    }

    @Test func signatureAssetPersistsInInMemorySwiftDataStore() throws {
        let configuration = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: SignatureAsset.self, SignerProfile.self, RecentDocument.self, configurations: configuration)
        let context = ModelContext(container)
        let data = SignatureRenderer.renderTextSignature("Jane Appleseed")
        let asset = SignatureAsset(name: "Jane", kind: .typedSignature, typedText: "Jane Appleseed", imageData: data)

        context.insert(asset)
        try context.save()

        let fetched = try context.fetch(FetchDescriptor<SignatureAsset>())
        #expect(fetched.count == 1)
        #expect(fetched.first?.typedText == "Jane Appleseed")
        #expect(fetched.first?.imageData?.isEmpty == false)
    }
}

enum PDFTestFactory {
    static func makeFixturePDF(pageCount: Int) throws -> URL {
        let url = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent("TinySignerFixture-\(UUID().uuidString).pdf")
        var mediaBox = CGRect(x: 0, y: 0, width: 612, height: 792)
        guard let context = CGContext(url as CFURL, mediaBox: &mediaBox, nil) else {
            throw NSError(domain: "TinySignerTests", code: 1)
        }

        for pageIndex in 0..<pageCount {
            context.beginPDFPage(nil)
            NSGraphicsContext.saveGraphicsState()
            let previous = NSGraphicsContext.current
            NSGraphicsContext.current = NSGraphicsContext(cgContext: context, flipped: false)
            let text = "Fixture Page \(pageIndex + 1)"
            let attributed = NSAttributedString(
                string: text,
                attributes: [
                    .font: NSFont.systemFont(ofSize: 28, weight: .semibold),
                    .foregroundColor: NSColor.black
                ]
            )
            attributed.draw(in: CGRect(x: 72, y: 700, width: 360, height: 42))
            NSGraphicsContext.current = previous
            NSGraphicsContext.restoreGraphicsState()
            context.endPDFPage()
        }

        context.closePDF()
        return url
    }
}
