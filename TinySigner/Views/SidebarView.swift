import SwiftUI

struct SidebarView: View {
    @ObservedObject var editor: PDFEditorStore
    var recentDocuments: [RecentDocument]
    var openRecent: (RecentDocument) -> Void

    var body: some View {
        List {
            Section("Document") {
                if let documentURL = editor.documentURL {
                    Label {
                        Text(documentURL.lastPathComponent)
                            .lineLimit(2)
                    } icon: {
                        Image(systemName: "doc.richtext")
                            .symbolRenderingMode(.hierarchical)
                    }
                    Label("\(editor.pageCount) pages", systemImage: "rectangle.stack")
                    Label("\(editor.fields.count) fields", systemImage: "signature")
                    Label("Page \(min(editor.currentPageIndex + 1, max(editor.pageCount, 1)))", systemImage: "number")
                } else {
                    Label("No PDF open", systemImage: "doc.badge.plus")
                        .foregroundStyle(.secondary)
                }
            }

            if !editor.fields.isEmpty {
                Section("Placed Fields") {
                    ForEach(editor.fields) { field in
                        Button {
                            editor.selectedFieldID = field.id
                        } label: {
                            HStack(spacing: 10) {
                                Image(systemName: icon(for: field.kind))
                                    .frame(width: 16)
                                    .foregroundStyle(.secondary)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(field.kind.title)
                                    Text("Page \(field.pageIndex + 1)")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                                Spacer()
                            }
                            .padding(.vertical, 4)
                            .padding(.horizontal, 6)
                            .background(field.id == editor.selectedFieldID ? Color.accentColor.opacity(0.16) : Color.clear, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
                            .contentShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                        }
                        .buttonStyle(.plain)
                        .tag(field.id)
                    }
                }
            }

            Section("Recent PDFs") {
                if recentDocuments.isEmpty {
                    Text("Recently opened PDFs appear here.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(recentDocuments.prefix(8)) { recent in
                        Button {
                            openRecent(recent)
                        } label: {
                            HStack(spacing: 10) {
                                Image(systemName: "clock.arrow.circlepath")
                                    .foregroundStyle(.secondary)
                                    .frame(width: 16)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(recent.displayName)
                                        .lineLimit(1)
                                    Text("\(recent.pageCount) pages")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                            }
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
        .listStyle(.sidebar)
        .navigationTitle("TinySigner")
    }

    private func icon(for kind: PlacedField.Kind) -> String {
        switch kind {
        case .signature: "signature"
        case .initials: "textformat.size.smaller"
        case .text: "text.cursor"
        case .date: "calendar"
        case .checkbox: "checkmark.square"
        }
    }
}
