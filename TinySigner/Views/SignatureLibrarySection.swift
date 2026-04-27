import AppKit
import SwiftData
import SwiftUI

struct SignerProfileCard: View {
    @Bindable var profile: SignerProfile

    var body: some View {
        InspectorSection("Signer", systemImage: "person.text.rectangle") {
            TextField("Full name", text: $profile.fullName)
                .textFieldStyle(.roundedBorder)
            TextField("Initials", text: $profile.initials)
                .textFieldStyle(.roundedBorder)
            TextField("Date format", text: $profile.preferredDateFormat)
                .textFieldStyle(.roundedBorder)
            Text("Example: \(PDFEditorStore.formattedDate(using: profile.preferredDateFormat))")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }
}

struct SignatureLibrarySection: View {
    @Bindable var profile: SignerProfile
    var signatureAssets: [SignatureAsset]
    @Binding var drawingStrokes: [SignatureStroke]
    var saveTypedSignature: () -> Void
    var saveTypedInitials: () -> Void
    var saveDrawnSignature: () -> Void
    var importSignatureImage: () -> Void
    var deleteAsset: (SignatureAsset, SignerProfile) -> Void

    var body: some View {
        InspectorSection("Signature Library", systemImage: "signature") {
            HStack {
                Button("Save Typed") { saveTypedSignature() }
                Button("Save Initials") { saveTypedInitials() }
            }
            .controlSize(.small)
            HStack {
                Button("Import Image") { importSignatureImage() }
                Button("Save Drawing") { saveDrawnSignature() }
            }
            .controlSize(.small)

            SignatureDrawingCanvas(strokes: $drawingStrokes)
                .frame(height: 118)
                .background(.background, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .stroke(.separator, lineWidth: 1)
                }
                .overlay(alignment: .topLeading) {
                    Text("Draw here")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .padding(8)
                }

            Button("Clear Drawing") {
                drawingStrokes = []
            }
            .buttonStyle(.link)
            .controlSize(.small)

            if signatureAssets.isEmpty {
                Text("Save or import a signature to reuse it on future PDFs.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } else {
                ForEach(signatureAssets, id: \.id) { asset in
                    SignatureAssetRow(asset: asset) {
                        deleteAsset(asset, profile)
                    }
                }
            }
        }
    }
}

private struct SignatureAssetRow: View {
    var asset: SignatureAsset
    var deleteAsset: () -> Void

    var body: some View {
        HStack(spacing: 10) {
            SignatureAssetPreview(asset: asset)
            VStack(alignment: .leading, spacing: 2) {
                Text(asset.name)
                    .lineLimit(1)
                Text(asset.kind.title)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Button(role: .destructive, action: deleteAsset) {
                Image(systemName: "trash")
            }
            .buttonStyle(.borderless)
        }
        .padding(8)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
    }
}

private struct SignatureAssetPreview: View {
    var asset: SignatureAsset

    var body: some View {
        Group {
            if let data = asset.imageData, let image = NSImage(data: data) {
                Image(nsImage: image)
                    .resizable()
                    .scaledToFit()
            } else {
                Image(systemName: "signature")
                    .foregroundStyle(.secondary)
            }
        }
        .frame(width: 58, height: 34)
        .padding(4)
        .background(.background, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
    }
}
