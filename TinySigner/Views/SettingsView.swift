import AppKit
import SwiftData
import SwiftUI
import UniformTypeIdentifiers

struct SettingsView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \SignerProfile.updatedAt, order: .reverse) private var profiles: [SignerProfile]
    @Query(sort: \SignatureAsset.updatedAt, order: .reverse) private var signatureAssets: [SignatureAsset]
    @State private var isShowingSignatureSetup = false
    @State private var drawingStrokes: [SignatureStroke] = []
    @State private var errorMessage: String?

    private var activeProfile: SignerProfile? { profiles.first }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                header

                if let profile = activeProfile {
                    profileSection(profile)
                    defaultAssetsSection(profile)
                    setupSection(profile)
                } else {
                    ContentUnavailableView(
                        "Preparing Settings",
                        systemImage: "gearshape",
                        description: Text("TinySigner is creating your local signer profile.")
                    )
                }
            }
            .padding(24)
            .frame(minWidth: 560, idealWidth: 640, maxWidth: .infinity, alignment: .topLeading)
        }
        .frame(minWidth: 560, minHeight: 520)
        .accessibilityIdentifier("settingsWindow")
        .onAppear(perform: ensureProfileExists)
        .sheet(isPresented: $isShowingSignatureSetup) {
            if let profile = activeProfile {
                SignatureSetupSheet(
                    profile: profile,
                    signatureAssets: signatureAssets,
                    drawingStrokes: $drawingStrokes,
                    saveTypedSignature: { saveTypedSignature(profile: profile) },
                    saveTypedInitials: { saveTypedInitials(profile: profile) },
                    saveDrawnSignature: { saveDrawnSignature(profile: profile) },
                    importSignatureImage: { importSignatureImage(profile: profile) },
                    deleteAsset: deleteAsset
                )
                .frame(minWidth: 520, minHeight: 560)
            }
        }
        .alert("TinySigner Settings", isPresented: Binding(
            get: { errorMessage != nil },
            set: { isPresented in if !isPresented { errorMessage = nil } }
        )) {
            Button("OK", role: .cancel) { errorMessage = nil }
        } message: {
            Text(errorMessage ?? "")
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 6) {
            Label("TinySigner Settings", systemImage: "gearshape")
                .font(.largeTitle.weight(.semibold))
                .accessibilityIdentifier("settingsTitle")
            Text("Manage the signer details and reusable signature assets TinySigner uses for new fields.")
                .foregroundStyle(.secondary)
        }
    }

    private func profileSection(_ profile: SignerProfile) -> some View {
        SettingsCard("Signer Profile", systemImage: "person.text.rectangle") {
            TextField("Full name", text: stringBinding(profile, keyPath: \.fullName))
                .textFieldStyle(.roundedBorder)
            TextField("Initials", text: stringBinding(profile, keyPath: \.initials))
                .textFieldStyle(.roundedBorder)
            TextField("Date format", text: stringBinding(profile, keyPath: \.preferredDateFormat))
                .textFieldStyle(.roundedBorder)
            Text("Example: \(PDFEditorStore.formattedDate(using: profile.preferredDateFormat))")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    private func defaultAssetsSection(_ profile: SignerProfile) -> some View {
        SettingsCard("Defaults", systemImage: "signature") {
            Picker("Default signature", selection: optionalAssetBinding(profile, keyPath: \.defaultSignatureAssetID)) {
                Text("Typed name fallback").tag(Optional<UUID>.none)
                ForEach(signatureAssets.filter { $0.kind != .initials }, id: \.id) { asset in
                    Text("\(asset.kind.title): \(asset.name)").tag(Optional(asset.id))
                }
            }

            Picker("Default initials", selection: optionalAssetBinding(profile, keyPath: \.defaultInitialsAssetID)) {
                Text("Typed initials fallback").tag(Optional<UUID>.none)
                ForEach(signatureAssets.filter { $0.kind == .initials }, id: \.id) { asset in
                    Text("\(asset.kind.title): \(asset.name)").tag(Optional(asset.id))
                }
            }

            Text("If no asset is selected, placed signature and initials fields use the typed profile text.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    private func setupSection(_ profile: SignerProfile) -> some View {
        SettingsCard("Signature Setup", systemImage: "square.and.pencil") {
            Button {
                isShowingSignatureSetup = true
            } label: {
                Label("Open Signature Setup", systemImage: "signature")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .accessibilityIdentifier("signatureSetupButton")

            if signatureAssets.isEmpty {
                Text("Create a typed signature, draw one, or import an image. Everything stays local on this Mac.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } else {
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 180), spacing: 10)], spacing: 10) {
                    ForEach(signatureAssets.prefix(6), id: \.id) { asset in
                        CompactSignatureAssetCard(asset: asset)
                    }
                }
            }
        }
    }

    private func ensureProfileExists() {
        guard profiles.isEmpty else { return }
        let profile = SignerProfile()
        modelContext.insert(profile)
        saveModelContext(errorPrefix: "TinySigner could not create a signer profile")
    }

    private func stringBinding(_ profile: SignerProfile, keyPath: ReferenceWritableKeyPath<SignerProfile, String>) -> Binding<String> {
        Binding(
            get: { profile[keyPath: keyPath] },
            set: { value in
                profile[keyPath: keyPath] = value
                profile.updatedAt = Date()
                saveModelContext(errorPrefix: "TinySigner could not save profile changes")
            }
        )
    }

    private func optionalAssetBinding(_ profile: SignerProfile, keyPath: ReferenceWritableKeyPath<SignerProfile, UUID?>) -> Binding<UUID?> {
        Binding(
            get: { profile[keyPath: keyPath] },
            set: { value in
                profile[keyPath: keyPath] = value
                profile.updatedAt = Date()
                saveModelContext(errorPrefix: "TinySigner could not save default signature settings")
            }
        )
    }

    private func saveTypedSignature(profile: SignerProfile) {
        guard let data = SignatureRenderer.renderTextSignature(profile.fullName) else {
            errorMessage = "Enter your full name before saving a typed signature."
            return
        }
        let asset = SignatureAsset(name: assetName(prefix: "Signature", value: profile.fullName), kind: .typedSignature, typedText: profile.fullName, imageData: data)
        modelContext.insert(asset)
        profile.defaultSignatureAssetID = asset.id
        profile.updatedAt = Date()
        saveModelContext(errorPrefix: "TinySigner could not save the typed signature")
    }

    private func saveTypedInitials(profile: SignerProfile) {
        guard let data = SignatureRenderer.renderTextSignature(profile.initials, size: CGSize(width: 260, height: 120)) else {
            errorMessage = "Enter initials before saving an initials asset."
            return
        }
        let asset = SignatureAsset(name: assetName(prefix: "Initials", value: profile.initials), kind: .initials, typedText: profile.initials, imageData: data)
        modelContext.insert(asset)
        profile.defaultInitialsAssetID = asset.id
        profile.updatedAt = Date()
        saveModelContext(errorPrefix: "TinySigner could not save the initials asset")
    }

    private func saveDrawnSignature(profile: SignerProfile) {
        guard let data = SignatureRenderer.renderStrokes(drawingStrokes) else {
            errorMessage = "Draw a signature before saving it."
            return
        }
        let asset = SignatureAsset(name: "Drawn Signature", kind: .drawnSignature, imageData: data)
        modelContext.insert(asset)
        profile.defaultSignatureAssetID = asset.id
        profile.updatedAt = Date()
        drawingStrokes = []
        saveModelContext(errorPrefix: "TinySigner could not save the drawn signature")
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
                errorMessage = "TinySigner could not read that image."
                return
            }
            let asset = SignatureAsset(name: url.deletingPathExtension().lastPathComponent, kind: .importedImage, imageData: pngData)
            modelContext.insert(asset)
            profile.defaultSignatureAssetID = asset.id
            profile.updatedAt = Date()
            saveModelContext(errorPrefix: "TinySigner could not save the imported image")
        } catch {
            errorMessage = error.localizedDescription
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
        saveModelContext(errorPrefix: "TinySigner could not delete that signature asset")
    }

    private func assetName(prefix: String, value: String) -> String {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? prefix : "\(prefix) - \(trimmed)"
    }

    private func saveModelContext(errorPrefix: String) {
        do {
            try modelContext.save()
        } catch {
            errorMessage = "\(errorPrefix): \(error.localizedDescription)"
        }
    }
}

struct SignatureSetupSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Bindable var profile: SignerProfile
    var signatureAssets: [SignatureAsset]
    @Binding var drawingStrokes: [SignatureStroke]
    var saveTypedSignature: () -> Void
    var saveTypedInitials: () -> Void
    var saveDrawnSignature: () -> Void
    var importSignatureImage: () -> Void
    var deleteAsset: (SignatureAsset, SignerProfile) -> Void

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Signature Setup")
                        .font(.title2.weight(.semibold))
                    Text("Create typed, drawn, or imported signature assets for reuse.")
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Button("Done") { dismiss() }
                    .keyboardShortcut(.defaultAction)
            }
            .padding(20)

            Divider()

            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    SignerProfileCard(profile: profile)
                    SignatureLibrarySection(
                        profile: profile,
                        signatureAssets: signatureAssets,
                        drawingStrokes: $drawingStrokes,
                        saveTypedSignature: saveTypedSignature,
                        saveTypedInitials: saveTypedInitials,
                        saveDrawnSignature: saveDrawnSignature,
                        importSignatureImage: importSignatureImage,
                        deleteAsset: deleteAsset
                    )
                }
                .padding(20)
            }
        }
    }
}

private struct SettingsCard<Content: View>: View {
    var title: String
    var systemImage: String
    private let content: Content

    init(_ title: String, systemImage: String, @ViewBuilder content: () -> Content) {
        self.title = title
        self.systemImage = systemImage
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label(title, systemImage: systemImage)
                .font(.headline)
                .symbolRenderingMode(.hierarchical)
            content
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(Color(nsColor: .separatorColor).opacity(0.55), lineWidth: 1)
        }
    }
}

private struct CompactSignatureAssetCard: View {
    var asset: SignatureAsset

    var body: some View {
        HStack(spacing: 10) {
            if let data = asset.imageData, let image = NSImage(data: data) {
                Image(nsImage: image)
                    .resizable()
                    .scaledToFit()
                    .frame(width: 58, height: 34)
                    .padding(4)
                    .background(.background, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
            } else {
                Image(systemName: "signature")
                    .foregroundStyle(.secondary)
                    .frame(width: 58, height: 34)
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(asset.name)
                    .font(.callout)
                    .lineLimit(1)
                Text(asset.kind.title)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
    }
}
