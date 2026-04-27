import AppKit
import CoreGraphics
import Foundation
import PDFKit
import SwiftData
import Testing
@testable import TinySigner

@MainActor
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

    @Test func signaturePlacementUsesClickedPointAsLineAnchor() {
        let store = PDFEditorStore()
        let pageBounds = CGRect(x: 0, y: 0, width: 612, height: 792)

        store.addField(
            kind: .signature,
            pageIndex: 0,
            at: CGPoint(x: 300, y: 200),
            pageBounds: pageBounds,
            profile: nil,
            defaultSignatureAssetID: nil,
            defaultInitialsAssetID: nil
        )

        let rect = store.fields[0].rectInPageSpace
        #expect(rect == CGRect(x: 190, y: 186, width: 220, height: 64))
        #expect(rect.minY < 200)
        #expect(rect.maxY > 200)
    }

    @Test func fieldRectResizeFromBottomRightClampsAndHonorsMinimumSize() {
        let pageBounds = CGRect(x: 0, y: 0, width: 300, height: 300)
        let field = CGRect(x: 50, y: 100, width: 100, height: 50)

        let expanded = field.resizedFromBottomRight(
            to: CGPoint(x: 220, y: 60),
            minimumSize: CGSize(width: 80, height: 30),
            clampedTo: pageBounds
        )
        let minimum = field.resizedFromBottomRight(
            to: CGPoint(x: 55, y: 148),
            minimumSize: CGSize(width: 80, height: 30),
            clampedTo: pageBounds
        )
        let clamped = field.resizedFromBottomRight(
            to: CGPoint(x: 260, y: -100),
            minimumSize: CGSize(width: 80, height: 30),
            clampedTo: pageBounds
        )

        #expect(expanded == CGRect(x: 50, y: 60, width: 170, height: 90))
        #expect(minimum == CGRect(x: 50, y: 120, width: 80, height: 30))
        #expect(clamped == CGRect(x: 50, y: 0, width: 210, height: 150))
    }

    @Test func drawnSignatureRendererNormalizesCanvasStrokes() throws {
        let data = try #require(SignatureRenderer.renderStrokes([
            SignatureStroke(points: [
                CGPoint(x: 18, y: 24),
                CGPoint(x: 74, y: 72),
                CGPoint(x: 132, y: 36),
                CGPoint(x: 186, y: 86),
                CGPoint(x: 248, y: 40)
            ])
        ]))
        let bitmap = try #require(NSBitmapImageRep(data: data))
        let renderedBounds = try #require(renderedAlphaBounds(in: bitmap))

        #expect(renderedBounds.width > CGFloat(bitmap.pixelsWide) / 2)
        #expect(renderedBounds.height > CGFloat(bitmap.pixelsHigh) / 4)
    }

    @Test func selectedFieldRendererDoesNotFillFieldInterior() throws {
        let bitmap = try #require(NSBitmapImageRep(
            bitmapDataPlanes: nil,
            pixelsWide: 140,
            pixelsHigh: 100,
            bitsPerSample: 8,
            samplesPerPixel: 4,
            hasAlpha: true,
            isPlanar: false,
            colorSpaceName: .deviceRGB,
            bytesPerRow: 0,
            bitsPerPixel: 0
        ))
        let graphicsContext = try #require(NSGraphicsContext(bitmapImageRep: bitmap))
        let field = PlacedField(
            kind: .checkbox,
            pageIndex: 0,
            rectInPageSpace: CGRect(x: 20, y: 20, width: 80, height: 50),
            text: "off",
            style: .checkbox
        )

        SigningFieldRenderer.draw(field: field, in: graphicsContext.cgContext, assetImageData: nil, selected: true)

        let centerPixel = try #require(bitmap.colorAt(x: 60, y: 50))
        #expect(centerPixel.alphaComponent == 0)
    }
}

@MainActor
struct SmartFieldDetectionTests {
    @Test func signatureDateAndCheckboxSuggestionsAreDetectedFromGeneratedPDF() throws {
        let fixtureURL = try PDFTestFactory.makeSmartFieldsFixturePDF()
        let document = try #require(PDFDocument(url: fixtureURL))

        let suggestions = PDFFieldDetectionService().detectSuggestions(in: document)

        #expect(suggestions.contains { $0.kind == .signature && $0.confidence == .high })
        #expect(suggestions.contains { $0.kind == .date && $0.confidence == .high })
        #expect(suggestions.contains { $0.kind == .checkbox && $0.confidence == .high })
    }

    @Test func unrelatedTextAndLinesDoNotCreateHighConfidenceSuggestions() throws {
        let fixtureURL = try PDFTestFactory.makeUnrelatedFixturePDF()
        let document = try #require(PDFDocument(url: fixtureURL))

        let suggestions = PDFFieldDetectionService().detectSuggestions(in: document)

        #expect(!suggestions.contains { $0.confidence == .high })
    }
}

@MainActor
struct SmartPlacementTests {
    @Test func acceptingSuggestionCreatesMatchingPlacedField() {
        let store = PDFEditorStore()
        let suggestion = DetectedFieldSuggestion(
            kind: .signature,
            pageIndex: 0,
            rectInPageSpace: CGRect(x: 80, y: 180, width: 220, height: 64),
            sourceLabel: "Signature",
            confidence: .high
        )
        store.fieldSuggestions = [suggestion]

        let accepted = store.acceptSuggestion(id: suggestion.id)

        #expect(accepted)
        #expect(store.fields.count == 1)
        #expect(store.fields.first?.kind == .signature)
        #expect(store.fields.first?.rectInPageSpace == suggestion.rectInPageSpace)
        #expect(store.fieldSuggestions.isEmpty)
    }

    @Test func compatiblePlacementNearSuggestionSnapsToSuggestionRect() {
        let store = PDFEditorStore()
        let suggestion = DetectedFieldSuggestion(
            kind: .date,
            pageIndex: 0,
            rectInPageSpace: CGRect(x: 340, y: 180, width: 140, height: 32),
            sourceLabel: "Date",
            confidence: .high
        )
        store.fieldSuggestions = [suggestion]

        store.addField(
            kind: .date,
            pageIndex: 0,
            at: CGPoint(x: suggestion.rectInPageSpace.midX + 6, y: suggestion.rectInPageSpace.midY - 5),
            pageBounds: CGRect(x: 0, y: 0, width: 612, height: 792),
            profile: nil,
            defaultSignatureAssetID: nil,
            defaultInitialsAssetID: nil
        )

        #expect(store.fields.first?.rectInPageSpace == suggestion.rectInPageSpace)
        #expect(store.fieldSuggestions.isEmpty)
    }

    @Test func undoRedoWorksAfterAcceptingSuggestion() {
        let store = PDFEditorStore()
        let suggestion = DetectedFieldSuggestion(
            kind: .checkbox,
            pageIndex: 0,
            rectInPageSpace: CGRect(x: 72, y: 120, width: 24, height: 24),
            sourceLabel: "checkbox",
            confidence: .high
        )
        store.fieldSuggestions = [suggestion]

        store.acceptSuggestion(id: suggestion.id)
        store.undo()
        #expect(store.fields.isEmpty)

        store.redo()
        #expect(store.fields.count == 1)
        #expect(store.fields.first?.kind == .checkbox)
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

    @Test func signerProfileDefaultAssetSelectionsPersist() throws {
        let configuration = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: SignatureAsset.self, SignerProfile.self, RecentDocument.self, configurations: configuration)
        let context = ModelContext(container)
        let signature = SignatureAsset(name: "Jane", kind: .typedSignature, typedText: "Jane Appleseed", imageData: SignatureRenderer.renderTextSignature("Jane Appleseed"))
        let initials = SignatureAsset(name: "JA", kind: .initials, typedText: "JA", imageData: SignatureRenderer.renderTextSignature("JA"))
        let profile = SignerProfile(fullName: "Jane Appleseed", initials: "JA")

        context.insert(signature)
        context.insert(initials)
        context.insert(profile)
        profile.defaultSignatureAssetID = signature.id
        profile.defaultInitialsAssetID = initials.id
        try context.save()

        let fetched = try #require(context.fetch(FetchDescriptor<SignerProfile>()).first)
        #expect(fetched.defaultSignatureAssetID == signature.id)
        #expect(fetched.defaultInitialsAssetID == initials.id)
    }

    @Test func exportIncludesAcceptedSuggestionsAndLeavesOriginalUntouched() throws {
        let fixtureURL = try PDFTestFactory.makeSmartFieldsFixturePDF()
        let originalData = try Data(contentsOf: fixtureURL)
        let outputURL = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent("TinySignerSmartExport-\(UUID().uuidString).pdf")
        let store = PDFEditorStore()
        let suggestion = DetectedFieldSuggestion(
            kind: .text,
            pageIndex: 0,
            rectInPageSpace: CGRect(x: 72, y: 610, width: 180, height: 36),
            sourceLabel: "Text",
            confidence: .high
        )

        try store.openPDF(from: fixtureURL)
        store.fieldSuggestions = [suggestion]
        store.acceptSuggestion(id: suggestion.id)
        try store.exportSignedPDF(to: outputURL, signatureAssets: [])

        #expect(try Data(contentsOf: fixtureURL) == originalData)
        #expect(PDFDocument(url: outputURL)?.pageCount == 1)
        #expect(store.exportReceipt?.url == outputURL)
        #expect((try FileManager.default.attributesOfItem(atPath: outputURL.path)[.size] as? NSNumber)?.intValue ?? 0 > 0)
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

    static func makeSmartFieldsFixturePDF() throws -> URL {
        try makeFormFixturePDF { context in
            drawText("11. Signature", in: CGRect(x: 72, y: 218, width: 140, height: 24))
            drawLine(from: CGPoint(x: 72, y: 210), to: CGPoint(x: 292, y: 210), context: context)

            drawText("Date", in: CGRect(x: 340, y: 218, width: 90, height: 24))
            drawLine(from: CGPoint(x: 340, y: 210), to: CGPoint(x: 480, y: 210), context: context)

            drawCheckbox(in: CGRect(x: 72, y: 150, width: 18, height: 18), context: context)
            drawText("I agree to the local signing terms.", in: CGRect(x: 100, y: 146, width: 300, height: 24))
        }
    }

    static func makeUnrelatedFixturePDF() throws -> URL {
        try makeFormFixturePDF { context in
            drawText("Fixture page with ordinary content", in: CGRect(x: 72, y: 700, width: 360, height: 30))
            drawLine(from: CGPoint(x: 72, y: 620), to: CGPoint(x: 292, y: 620), context: context)
        }
    }

    private static func makeFormFixturePDF(draw: (CGContext) -> Void) throws -> URL {
        let url = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent("TinySignerSmartFixture-\(UUID().uuidString).pdf")
        var mediaBox = CGRect(x: 0, y: 0, width: 612, height: 792)
        guard let context = CGContext(url as CFURL, mediaBox: &mediaBox, nil) else {
            throw NSError(domain: "TinySignerTests", code: 2)
        }

        context.beginPDFPage(nil)
        NSGraphicsContext.saveGraphicsState()
        let previous = NSGraphicsContext.current
        NSGraphicsContext.current = NSGraphicsContext(cgContext: context, flipped: false)
        drawText("TinySigner Smart Fixture", in: CGRect(x: 72, y: 700, width: 420, height: 36))
        draw(context)
        NSGraphicsContext.current = previous
        NSGraphicsContext.restoreGraphicsState()
        context.endPDFPage()
        context.closePDF()
        return url
    }

    private static func drawText(_ text: String, in rect: CGRect) {
        let attributed = NSAttributedString(
            string: text,
            attributes: [
                .font: NSFont.systemFont(ofSize: 14, weight: .regular),
                .foregroundColor: NSColor.black
            ]
        )
        attributed.draw(in: rect)
    }

    private static func drawLine(from start: CGPoint, to end: CGPoint, context: CGContext) {
        context.saveGState()
        context.setStrokeColor(NSColor.black.cgColor)
        context.setLineWidth(1.2)
        context.move(to: start)
        context.addLine(to: end)
        context.strokePath()
        context.restoreGState()
    }

    private static func drawCheckbox(in rect: CGRect, context: CGContext) {
        context.saveGState()
        context.setStrokeColor(NSColor.black.cgColor)
        context.setLineWidth(1.4)
        context.stroke(rect)
        context.restoreGState()
    }
}

private func renderedAlphaBounds(in bitmap: NSBitmapImageRep) -> CGRect? {
    var minX = bitmap.pixelsWide
    var minY = bitmap.pixelsHigh
    var maxX = 0
    var maxY = 0
    var foundPixel = false

    for y in 0..<bitmap.pixelsHigh {
        for x in 0..<bitmap.pixelsWide {
            guard let color = bitmap.colorAt(x: x, y: y), color.alphaComponent > 0.01 else { continue }
            foundPixel = true
            minX = min(minX, x)
            minY = min(minY, y)
            maxX = max(maxX, x)
            maxY = max(maxY, y)
        }
    }

    guard foundPixel else { return nil }
    return CGRect(
        x: CGFloat(minX),
        y: CGFloat(minY),
        width: CGFloat(maxX - minX + 1),
        height: CGFloat(maxY - minY + 1)
    )
}
