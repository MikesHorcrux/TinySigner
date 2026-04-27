import AppKit
import PDFKit
import SwiftUI

struct PDFKitDocumentView: NSViewRepresentable {
    @ObservedObject var editor: PDFEditorStore
    var profile: SignerProfile?
    var signatureAssets: [SignatureAsset]

    func makeNSView(context: Context) -> PDFKitDocumentContainerView {
        let view = PDFKitDocumentContainerView()
        view.pdfView.onSelectField = { id in
            editor.selectedFieldID = id
        }
        view.pdfView.onBeginDragField = {
            editor.beginFieldDrag()
        }
        view.pdfView.onFinishDragField = {
            editor.finishFieldDrag()
        }
        view.pdfView.onDeleteSelectedField = {
            editor.deleteSelectedField()
        }
        view.pdfView.onPageChange = { pageIndex in
            editor.currentPageIndex = pageIndex
        }
        return view
    }

    func updateNSView(_ nsView: PDFKitDocumentContainerView, context: Context) {
        let defaultSignatureID = profile?.defaultSignatureAssetID ?? signatureAssets.first(where: { $0.kind != .initials })?.id
        let defaultInitialsID = profile?.defaultInitialsAssetID ?? signatureAssets.first(where: { $0.kind == .initials })?.id
        let assetsByID = Dictionary(uniqueKeysWithValues: signatureAssets.compactMap { asset -> (UUID, Data)? in
            guard let imageData = asset.imageData else { return nil }
            return (asset.id, imageData)
        })

        nsView.pdfView.onCreateField = { tool, pageIndex, point, pageBounds in
            guard let kind = tool.fieldKind else { return }
            editor.addField(
                kind: kind,
                pageIndex: pageIndex,
                at: point,
                pageBounds: pageBounds,
                profile: profile,
                defaultSignatureAssetID: defaultSignatureID,
                defaultInitialsAssetID: defaultInitialsID
            )
        }
        nsView.pdfView.onMoveField = { id, rect, pageBounds in
            editor.updateFieldRect(id: id, rect: rect, pageBounds: pageBounds, recordUndo: false)
        }

        nsView.configure(
            document: editor.document,
            fields: editor.fields,
            selectedFieldID: editor.selectedFieldID,
            activeTool: editor.activeTool,
            zoomScale: editor.zoomScale,
            signatureAssetsByID: assetsByID,
            refreshToken: editor.refreshToken
        )
    }
}

final class PDFKitDocumentContainerView: NSView {
    let pdfView = SigningPDFView()
    private let thumbnailView = PDFThumbnailView()
    private let splitView = NSSplitView()
    private var currentDocument: PDFDocument?
    private var lastPreviewRenderState: PreviewRenderState?

    private struct PreviewRenderState: Equatable {
        var fields: [PlacedField]
        var selectedFieldID: UUID?
        var signatureAssetsByID: [UUID: Data]
        var refreshToken: UUID
    }

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        setupViews()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupViews()
    }

    func configure(
        document: PDFDocument?,
        fields: [PlacedField],
        selectedFieldID: UUID?,
        activeTool: SigningTool,
        zoomScale: CGFloat,
        signatureAssetsByID: [UUID: Data],
        refreshToken: UUID
    ) {
        if currentDocument !== document {
            if let currentDocument {
                PDFDocumentService.removeTinySignerPreviewAnnotations(from: currentDocument)
            }
            if let document {
                PDFDocumentService.removeTinySignerPreviewAnnotations(from: document)
            }
            currentDocument = document
            pdfView.document = document
            thumbnailView.pdfView = pdfView
            pdfView.goToFirstPage(nil)
            lastPreviewRenderState = nil
        }

        pdfView.activeTool = activeTool
        pdfView.fields = fields
        pdfView.selectedFieldID = selectedFieldID
        pdfView.signatureAssetsByID = signatureAssetsByID
        pdfView.minScaleFactor = 0.35
        pdfView.maxScaleFactor = 3.0
        if abs(pdfView.scaleFactor - zoomScale) > 0.01 {
            pdfView.autoScales = false
            pdfView.scaleFactor = zoomScale
        }

        let previewRenderState = PreviewRenderState(
            fields: fields,
            selectedFieldID: selectedFieldID,
            signatureAssetsByID: signatureAssetsByID,
            refreshToken: refreshToken
        )
        if lastPreviewRenderState != previewRenderState {
            lastPreviewRenderState = previewRenderState
            pdfView.refreshSigningOverlay()
        }
    }

    private func setupViews() {
        splitView.isVertical = true
        splitView.dividerStyle = .thin
        splitView.translatesAutoresizingMaskIntoConstraints = false

        thumbnailView.translatesAutoresizingMaskIntoConstraints = false
        thumbnailView.thumbnailSize = NSSize(width: 60, height: 84)
        thumbnailView.backgroundColor = .clear

        pdfView.translatesAutoresizingMaskIntoConstraints = false
        pdfView.displayMode = .singlePageContinuous
        pdfView.displayDirection = .vertical
        pdfView.displaysPageBreaks = true
        pdfView.autoScales = false
        pdfView.scaleFactor = 1.0
        pdfView.backgroundColor = NSColor.windowBackgroundColor

        splitView.addArrangedSubview(thumbnailView)
        splitView.addArrangedSubview(pdfView)
        addSubview(splitView)

        NSLayoutConstraint.activate([
            splitView.leadingAnchor.constraint(equalTo: leadingAnchor),
            splitView.trailingAnchor.constraint(equalTo: trailingAnchor),
            splitView.topAnchor.constraint(equalTo: topAnchor),
            splitView.bottomAnchor.constraint(equalTo: bottomAnchor),
            thumbnailView.widthAnchor.constraint(equalToConstant: 104)
        ])
    }
}
