import SwiftUI

struct WelcomeView: View {
    var recentDocuments: [RecentDocument]
    var openPDF: () -> Void
    var openRecent: (RecentDocument) -> Void

    var body: some View {
        VStack(spacing: 28) {
            Spacer()

            VStack(spacing: 14) {
                Image(systemName: "signature")
                    .font(.system(size: 54, weight: .light))
                    .symbolRenderingMode(.hierarchical)
                Text("TinySigner")
                    .font(.largeTitle.weight(.semibold))
                    .accessibilityIdentifier("welcomeTitle")
                Text("Open a PDF, place signatures and form fields, then export a flattened signed copy.")
                    .font(.title3)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: 560)
            }

            Button(action: openPDF) {
                Label("Open PDF", systemImage: "doc.badge.plus")
                    .font(.headline)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 8)
            }
            .buttonStyle(.borderedProminent)
            .accessibilityIdentifier("welcomeOpenPDFButton")
            .keyboardShortcut("o", modifiers: .command)

            if !recentDocuments.isEmpty {
                VStack(alignment: .leading, spacing: 10) {
                    Text("Recent PDFs")
                        .font(.headline)
                    ForEach(recentDocuments.prefix(4)) { recent in
                        Button {
                            openRecent(recent)
                        } label: {
                            HStack {
                                Image(systemName: "doc.text")
                                Text(recent.displayName)
                                Spacer()
                                Text("\(recent.pageCount) pages")
                                    .foregroundStyle(.secondary)
                            }
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(18)
                .frame(width: 440)
                .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
            }

            Spacer()
        }
        .padding(40)
    }
}
