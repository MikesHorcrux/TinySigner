import AppKit
import SwiftUI

struct InspectorPanelView: View {
    @ObservedObject var editor: PDFEditorStore
    var profile: SignerProfile?
    var signatureAssets: [SignatureAsset]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                toolSection
                suggestionsSection
                selectedFieldSection
            }
            .padding(18)
        }
        .frame(minWidth: 290, idealWidth: 320, maxWidth: 380)
        .background(.bar)
    }

    private var toolSection: some View {
        InspectorSection("Tools", systemImage: "wand.and.sparkles") {
            Text("Choose a tool, then click the PDF. Existing fields can be selected, moved, resized, or deleted.")
                .font(.caption)
                .foregroundStyle(.secondary)
                .accessibilityIdentifier("toolsInspectorTitle")

            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 8) {
                ForEach(SigningTool.allCases) { tool in
                    SigningToolButton(tool: tool, isSelected: editor.activeTool == tool) {
                        editor.activeTool = tool
                    }
                }
            }
        }
    }

    @ViewBuilder
    private var suggestionsSection: some View {
        if editor.hasDocument {
            InspectorSection("Smart Suggestions", systemImage: "sparkles.rectangle.stack") {
                if editor.fieldSuggestions.isEmpty {
                    Text("No smart fields are waiting. Use the tools above to place fields manually.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                } else {
                    let highConfidenceCount = editor.fieldSuggestions.filter { $0.confidence == .high }.count
                    Text("\(editor.fieldSuggestions.count) likely fields found. High-confidence items can be accepted in one pass; medium items stay manual.")
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    Button {
                        editor.acceptHighConfidenceSuggestions(
                            profile: profile,
                            defaultSignatureAssetID: defaultSignatureID,
                            defaultInitialsAssetID: defaultInitialsID
                        )
                    } label: {
                        Label("Accept \(highConfidenceCount) High Confidence", systemImage: "checkmark.seal")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.small)
                    .disabled(highConfidenceCount == 0)
                    .accessibilityIdentifier("acceptSmartSuggestionsButton")

                    VStack(spacing: 8) {
                        ForEach(editor.fieldSuggestions.prefix(8)) { suggestion in
                            SuggestionRow(suggestion: suggestion) {
                                editor.acceptSuggestion(
                                    id: suggestion.id,
                                    profile: profile,
                                    defaultSignatureAssetID: defaultSignatureID,
                                    defaultInitialsAssetID: defaultInitialsID
                                )
                            }
                        }
                    }

                    if editor.fieldSuggestions.count > 8 {
                        Text("+ \(editor.fieldSuggestions.count - 8) more suggestions are highlighted on the PDF.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
    }

    @ViewBuilder
    private var selectedFieldSection: some View {
        InspectorSection("Selected Field", systemImage: "slider.horizontal.3") {
            if let field = editor.selectedField {
                VStack(spacing: 8) {
                    LabeledContent("Type", value: field.kind.title)
                    LabeledContent("Page", value: "\(field.pageIndex + 1)")
                }
                .font(.callout)

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
                .controlSize(.small)
            } else {
                ContentUnavailableView(
                    "No Field Selected",
                    systemImage: "selection.pin.in.out",
                    description: Text("Select a field on the PDF to edit its value, size, or signature source.")
                )
                .controlSize(.small)
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

    private var defaultSignatureID: UUID? {
        profile?.defaultSignatureAssetID ?? signatureAssets.first(where: { $0.kind != .initials })?.id
    }

    private var defaultInitialsID: UUID? {
        profile?.defaultInitialsAssetID ?? signatureAssets.first(where: { $0.kind == .initials })?.id
    }
}

private struct SuggestionRow: View {
    var suggestion: DetectedFieldSuggestion
    var accept: () -> Void

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: icon)
                .foregroundStyle(suggestion.confidence.tint)
                .frame(width: 18)

            VStack(alignment: .leading, spacing: 2) {
                Text(suggestion.kind.title)
                    .font(.callout.weight(.semibold))
                Text("Page \(suggestion.pageIndex + 1) · \(suggestion.confidence.title) · \(suggestion.sourceLabel)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            Spacer()

            Button("Accept", action: accept)
                .controlSize(.small)
        }
        .padding(8)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
    }

    private var icon: String {
        switch suggestion.kind {
        case .signature: "signature"
        case .initials: "textformat.size.smaller"
        case .text: "text.cursor"
        case .date: "calendar"
        case .checkbox: "checkmark.square"
        }
    }
}

private extension DetectionConfidence {
    var tint: Color {
        switch self {
        case .high: .blue
        case .medium: .teal
        case .low: .secondary
        }
    }
}

private struct SigningToolButton: View {
    var tool: SigningTool
    var isSelected: Bool
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 6) {
                Image(systemName: tool.systemImage)
                    .font(.system(size: 16, weight: .semibold))
                    .symbolRenderingMode(.hierarchical)
                Text(tool.title)
                    .font(.caption.weight(.semibold))
                    .lineLimit(1)
            }
            .frame(maxWidth: .infinity, minHeight: 52)
            .contentShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        }
        .buttonStyle(.plain)
        .foregroundStyle(isSelected ? Color.accentColor : Color.primary)
        .background(selectionBackground, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(isSelected ? Color.accentColor.opacity(0.75) : Color(nsColor: .separatorColor).opacity(0.55), lineWidth: 1)
        }
        .help(tool.title)
    }

    private var selectionBackground: some ShapeStyle {
        isSelected ? Color.accentColor.opacity(0.16) : Color(nsColor: .controlBackgroundColor).opacity(0.36)
    }
}
