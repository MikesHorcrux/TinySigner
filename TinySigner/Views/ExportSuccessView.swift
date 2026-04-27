import SwiftUI

struct ExportSuccessView: View {
    var url: URL
    var openSignedPDF: () -> Void
    var revealInFinder: () -> Void
    var signAnother: () -> Void

    var body: some View {
        VStack(spacing: 20) {
            ZStack {
                Circle()
                    .fill(Color.green.opacity(0.16))
                    .frame(width: 72, height: 72)
                Image(systemName: "checkmark.seal.fill")
                    .font(.system(size: 38, weight: .semibold))
                    .foregroundStyle(.green)
                    .symbolRenderingMode(.hierarchical)
            }

            VStack(spacing: 6) {
                Text("Signed PDF Exported")
                    .font(.title2.weight(.semibold))
                    .accessibilityIdentifier("exportSuccessTitle")
                Text(url.lastPathComponent)
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
                    .multilineTextAlignment(.center)
            }

            HStack(spacing: 10) {
                Button(action: openSignedPDF) {
                    Label("Open Signed PDF", systemImage: "doc.richtext")
                }
                Button(action: revealInFinder) {
                    Label("Reveal in Finder", systemImage: "finder")
                }
                Button(action: signAnother) {
                    Label("Sign Another", systemImage: "doc.badge.plus")
                }
            }
            .controlSize(.large)
        }
        .padding(30)
        .frame(minWidth: 460)
    }
}
