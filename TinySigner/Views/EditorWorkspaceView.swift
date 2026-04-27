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

            HStack(spacing: 12) {
                Label(editor.statusMessage, systemImage: "info.circle")
                    .lineLimit(1)
                    .foregroundStyle(.secondary)
                Spacer()
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

                Button("Actual Size") {
                    editor.resetZoom()
                }
            }
            .buttonStyle(.borderless)
            .font(.callout)
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("editorWorkspace")
    }
}
