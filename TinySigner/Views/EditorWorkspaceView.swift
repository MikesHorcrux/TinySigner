import SwiftUI

struct EditorWorkspaceView: View {
    @ObservedObject var editor: PDFEditorStore
    var profile: SignerProfile?
    var signatureAssets: [SignatureAsset]

    var body: some View {
        VStack(spacing: 0) {
            PDFKitDocumentView(editor: editor, profile: profile, signatureAssets: signatureAssets)
                .frame(minWidth: 560, minHeight: 520)

            Divider()

            footerBar
        }
        .background(.background)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("editorWorkspace")
    }

    private var footerBar: some View {
        HStack(spacing: 12) {
            Label(editor.statusMessage, systemImage: editor.hasDocument ? "doc.viewfinder" : "info.circle")
                .lineLimit(1)
                .foregroundStyle(.secondary)

            Spacer()

            HStack(spacing: 8) {
                Button {
                    editor.zoomOut()
                } label: {
                    Image(systemName: "minus.magnifyingglass")
                }
                .help("Zoom out")

                Text("\(Int(editor.zoomScale * 100))%")
                    .monospacedDigit()
                    .foregroundStyle(.secondary)
                    .frame(width: 48)

                Button {
                    editor.zoomIn()
                } label: {
                    Image(systemName: "plus.magnifyingglass")
                }
                .help("Zoom in")

                Divider()
                    .frame(height: 16)

                Button("Actual Size") {
                    editor.resetZoom()
                }
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background(.regularMaterial, in: Capsule())
        }
        .buttonStyle(.borderless)
        .font(.callout)
        .padding(.horizontal, 14)
        .padding(.vertical, 9)
        .background(.bar)
    }
}
