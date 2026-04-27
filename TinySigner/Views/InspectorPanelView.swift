import AppKit
import SwiftData
import SwiftUI
import UniformTypeIdentifiers

struct InspectorPanelView: View {
    @Environment(\.modelContext) private var modelContext
    @ObservedObject var editor: PDFEditorStore
    var profile: SignerProfile?
    var signatureAssets: [SignatureAsset]
    @State private var drawingStrokes: [SignatureStroke] = []

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                toolSection

                if let profile {
                    ProfileCard(profile: profile)
                    SignatureAssetSection(
                        profile: profile,
                        signatureAssets: signatureAssets,
                        drawingStrokes: $drawingStrokes,
                        saveTypedSignature: { saveTypedSignature(profile: profile) },
                        saveTypedInitials: { saveTypedInitials(profile: profile) },
                        saveDrawnSignature: { saveDrawnSignature(profile: profile) },
                        importSignatureImage: { importSignatureImage(profile: profile) },
                        deleteAsset: deleteAsset
                    )
                }

                selectedFieldSection
            }
            .padding(18)
        }
        .frame(minWidth: 290, idealWidth: 320, maxWidth: 380)
        .background(.thinMaterial)
    }

    private var toolSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Tools")
                .font(.headline)
                .accessibilityIdentifier("toolsInspectorTitle")
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 8) {
                ForEach(SigningTool.allCases) { tool in
                    Button {
                        editor.activeTool = tool
                    } label: {
                        Label(tool.title, systemImage: tool.systemImage)
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                    .tint(editor.activeTool == tool ? .accentColor : nil)
                }
            }
            Text("Click a tool, then click the PDF. Drag placed fields to reposition; movement snaps to a 2 point grid.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    @ViewBuilder
    private var selectedFieldSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Selected Field")
                .font(.headline)

            if let field = editor.selectedField {
                LabeledContent("Type", value: field.kind.title)
                LabeledContent("Page", value: "\(field.pageIndex + 1)")

                if field.kind != .checkbox {
                    TextField("Value", text: Binding(
                        get: { editor.selectedField?.text ?? "" },
                        set: { value in editor.updateSelectedField { $0.text = value } }
                    ))
                    .textFieldStyle(.roundedBorder)
                } else {
                    Toggle("Checked", isOn: Binding(
                        get: { editor.selectedField?.text.lowercased() != "off" },
                        set: { isOn in editor.updateSelectedField { $0.text = isOn ? "on" : "off" } }
                    ))
                }

                if field.kind == .signature || field.kind == .initials {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Signature Source")
                            .font(.subheadline.weight(.semibold))
                        Picker("Signature Source", selection: Binding<UUID?>(
                            get: { editor.selectedField?.signatureAssetID },
                            set: { value in editor.updateSelectedField { $0.signatureAssetID = value } }
                        )) {
                            Text(typedSourceTitle(for: field.kind)).tag(Optional<UUID>.none)
                            ForEach(assetChoices(for: field.kind), id: \.id) { asset in
                                Text(assetSourceTitle(asset)).tag(Optional(asset.id))
                            }
                        }
                        .pickerStyle(.menu)
                        Text("Choose Typed name/initials, a saved drawing, or an imported image for this placed field.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }

                Stepper(value: Binding(
                    get: { Double(editor.selectedField?.rectInPageSpace.size.width ?? 0) },
                    set: { value in editor.resizeSelectedField(width: CGFloat(value)) }
                ), in: 12...720, step: 2) {
                    Text("Width: \(Int(field.rectInPageSpace.width))")
                }

                Stepper(value: Binding(
                    get: { Double(editor.selectedField?.rectInPageSpace.size.height ?? 0) },
                    set: { value in editor.resizeSelectedField(height: CGFloat(value)) }
                ), in: 12...260, step: 2) {
                    Text("Height: \(Int(field.rectInPageSpace.height))")
                }

                HStack {
                    Button("Delete", role: .destructive) {
                        editor.deleteField(id: field.id)
                    }
                    Button("Today") {
                        editor.updateSelectedField { $0.text = PDFEditorStore.formattedDate(using: profile?.preferredDateFormat) }
                    }
                    .disabled(field.kind != .date)
                }
            } else {
                Text("Select a field on the PDF to edit its text, size, or signature asset.")
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private func typedSourceTitle(for kind: PlacedField.Kind) -> String {
        switch kind {
        case .signature:
            let name = profile?.fullName.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            return name.isEmpty ? "Typed name from Value" : "Typed name: \(name)"
        case .initials:
            let initials = profile?.initials.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            return initials.isEmpty ? "Typed initials from Value" : "Typed initials: \(initials)"
        case .text, .date, .checkbox:
            return "Typed"
        }
    }

    private func assetSourceTitle(_ asset: SignatureAsset) -> String {
        "\(asset.kind.title): \(asset.name)"
    }

    private func assetChoices(for kind: PlacedField.Kind) -> [SignatureAsset] {
        switch kind {
        case .initials:
            signatureAssets.filter { $0.kind == .initials }
        case .signature:
            signatureAssets.filter { $0.kind != .initials }
        case .text, .date, .checkbox:
            []
        }
    }

    private func saveTypedSignature(profile: SignerProfile) {
        guard let data = SignatureRenderer.renderTextSignature(profile.fullName) else {
            editor.lastError = "Enter your full name before saving a typed signature."
            return
        }
        let asset = SignatureAsset(name: assetName(prefix: "Signature", value: profile.fullName), kind: .typedSignature, typedText: profile.fullName, imageData: data)
        modelContext.insert(asset)
        profile.defaultSignatureAssetID = asset.id
        profile.updatedAt = Date()
        saveSignatureLibrary()
    }

    private func saveTypedInitials(profile: SignerProfile) {
        guard let data = SignatureRenderer.renderTextSignature(profile.initials, size: CGSize(width: 260, height: 120)) else {
            editor.lastError = "Enter initials before saving an initials asset."
            return
        }
        let asset = SignatureAsset(name: assetName(prefix: "Initials", value: profile.initials), kind: .initials, typedText: profile.initials, imageData: data)
        modelContext.insert(asset)
        profile.defaultInitialsAssetID = asset.id
        profile.updatedAt = Date()
        saveSignatureLibrary()
    }

    private func saveDrawnSignature(profile: SignerProfile) {
        guard let data = SignatureRenderer.renderStrokes(drawingStrokes) else {
            editor.lastError = "Draw a signature before saving it."
            return
        }
        let asset = SignatureAsset(name: "Drawn Signature", kind: .drawnSignature, imageData: data)
        modelContext.insert(asset)
        profile.defaultSignatureAssetID = asset.id
        profile.updatedAt = Date()
        drawingStrokes = []
        saveSignatureLibrary()
    }

    private func importSignatureImage(profile: SignerProfile) {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.image]
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        panel.canChooseFiles = true
        panel.message = "Choose a transparent PNG or image to use as your signature."
        guard panel.runModal() == .OK, let url = panel.url else { return }

        do {
            let data = try Data(contentsOf: url)
            guard let image = NSImage(data: data), let pngData = image.pngData() else {
                editor.lastError = "TinySigner could not read that image."
                return
            }
            let asset = SignatureAsset(name: url.deletingPathExtension().lastPathComponent, kind: .importedImage, imageData: pngData)
            modelContext.insert(asset)
            profile.defaultSignatureAssetID = asset.id
            profile.updatedAt = Date()
            saveSignatureLibrary()
        } catch {
            editor.lastError = error.localizedDescription
        }
    }

    private func deleteAsset(_ asset: SignatureAsset, profile: SignerProfile) {
        if profile.defaultSignatureAssetID == asset.id {
            profile.defaultSignatureAssetID = nil
        }
        if profile.defaultInitialsAssetID == asset.id {
            profile.defaultInitialsAssetID = nil
        }
        modelContext.delete(asset)
        profile.updatedAt = Date()
        saveSignatureLibrary()
    }

    private func assetName(prefix: String, value: String) -> String {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? prefix : "\(prefix) - \(trimmed)"
    }

    private func saveSignatureLibrary() {
        do {
            try modelContext.save()
        } catch {
            editor.lastError = "TinySigner could not save the signature library: \(error.localizedDescription)"
        }
    }
}

private struct ProfileCard: View {
    @Bindable var profile: SignerProfile

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Signer")
                .font(.headline)
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

private struct SignatureAssetSection: View {
    @Bindable var profile: SignerProfile
    var signatureAssets: [SignatureAsset]
    @Binding var drawingStrokes: [SignatureStroke]
    var saveTypedSignature: () -> Void
    var saveTypedInitials: () -> Void
    var saveDrawnSignature: () -> Void
    var importSignatureImage: () -> Void
    var deleteAsset: (SignatureAsset, SignerProfile) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Signature Library")
                .font(.headline)

            HStack {
                Button("Save Typed") { saveTypedSignature() }
                Button("Save Initials") { saveTypedInitials() }
            }
            HStack {
                Button("Import Image") { importSignatureImage() }
                Button("Save Drawing") { saveDrawnSignature() }
            }

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

            if signatureAssets.isEmpty {
                Text("Save or import a signature to reuse it on future PDFs.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } else {
                ForEach(signatureAssets, id: \.id) { asset in
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
                        Button(role: .destructive) {
                            deleteAsset(asset, profile)
                        } label: {
                            Image(systemName: "trash")
                        }
                        .buttonStyle(.borderless)
                    }
                    .padding(8)
                    .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                }
            }
        }
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
