import SwiftUI

struct WelcomeView: View {
    var recentDocuments: [RecentDocument]
    var openPDF: () -> Void
    var openRecent: (RecentDocument) -> Void

    var body: some View {
        ZStack {
            welcomeBackdrop

            VStack(spacing: 26) {
                Spacer(minLength: 24)
                heroCard

                if !recentDocuments.isEmpty {
                    recentDocumentsCard
                }

                Spacer(minLength: 24)
            }
            .padding(42)
        }
    }

    private var welcomeBackdrop: some View {
        ZStack {
            Rectangle()
                .fill(.background)
            RadialGradient(
                colors: [Color.accentColor.opacity(0.18), Color.clear],
                center: .topLeading,
                startRadius: 20,
                endRadius: 620
            )
            RadialGradient(
                colors: [Color.cyan.opacity(0.10), Color.clear],
                center: .bottomTrailing,
                startRadius: 80,
                endRadius: 540
            )
        }
        .ignoresSafeArea()
    }

    private var heroCard: some View {
        VStack(spacing: 24) {
            VStack(spacing: 16) {
                ZStack {
                    Circle()
                        .fill(.regularMaterial)
                        .frame(width: 82, height: 82)
                    Image(systemName: "signature")
                        .font(.system(size: 42, weight: .light))
                        .symbolRenderingMode(.hierarchical)
                }

                VStack(spacing: 8) {
                    Text("TinySigner")
                        .font(.system(size: 44, weight: .semibold, design: .rounded))
                        .accessibilityIdentifier("welcomeTitle")
                    Text("Local PDF signing with clean placement tools and flattened export.")
                        .font(.title3)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .frame(maxWidth: 620)
                }
            }

            HStack(spacing: 10) {
                FeaturePill(title: "Local-first", systemImage: "lock.doc")
                FeaturePill(title: "Original untouched", systemImage: "doc.on.doc")
                FeaturePill(title: "Flattened export", systemImage: "square.and.arrow.down")
            }

            Button(action: openPDF) {
                Label("Open PDF", systemImage: "doc.badge.plus")
                    .font(.headline)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .accessibilityIdentifier("welcomeOpenPDFButton")
            .keyboardShortcut("o", modifiers: .command)
        }
        .padding(34)
        .frame(maxWidth: 760)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 28, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .stroke(Color.primary.opacity(0.10), lineWidth: 1)
        }
    }

    private var recentDocumentsCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("Recent PDFs", systemImage: "clock.arrow.circlepath")
                .font(.headline)

            ForEach(recentDocuments.prefix(4)) { recent in
                Button {
                    openRecent(recent)
                } label: {
                    HStack(spacing: 10) {
                        Image(systemName: "doc.text")
                            .foregroundStyle(.secondary)
                            .frame(width: 18)
                        Text(recent.displayName)
                            .lineLimit(1)
                        Spacer()
                        Text("\(recent.pageCount) pages")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .padding(.vertical, 4)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(18)
        .frame(width: 480)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
    }
}

private struct FeaturePill: View {
    var title: String
    var systemImage: String

    var body: some View {
        Label(title, systemImage: systemImage)
            .font(.caption.weight(.semibold))
            .foregroundStyle(.secondary)
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(.regularMaterial, in: Capsule())
    }
}
