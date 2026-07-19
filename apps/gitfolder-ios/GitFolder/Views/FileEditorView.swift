import SwiftUI

/// View and edit a single text file. Markdown renders through the bundled Nizel
/// renderer; SVG renders as an image — both with an Edit toggle to edit the source.
/// Other text files open straight in the editor. Saving writes the file as one commit.
struct FileEditorView: View {
    @Environment(AppModel.self) private var model
    let path: String
    let name: String

    @State private var text = ""
    @State private var original = ""
    @State private var isLoading = true
    @State private var loadError: String?
    @State private var editing = false
    @State private var seededMode = false

    private var isMarkdown: Bool {
        let l = name.lowercased()
        return l.hasSuffix(".md") || l.hasSuffix(".markdown")
    }
    private var isSVG: Bool { FileKind.isSVG(name) }
    private var hasPreview: Bool { isMarkdown || isSVG }
    private var isDirty: Bool { text != original }

    var body: some View {
        Group {
            if isLoading {
                ProgressView()
            } else if let loadError {
                ContentUnavailableView("Couldn't open file", systemImage: "doc.badge.exclamationmark", description: Text(loadError))
            } else if editing || !hasPreview {
                TextEditor(text: $text)
                    .font(.system(.body, design: .monospaced))
                    .autocorrectionDisabled()
                    .textInputAutocapitalization(.never)
                    .padding(.horizontal, 4)
            } else if isMarkdown {
                MarkdownWebView(markdown: text)
            } else { // SVG preview
                SVGWebView(svg: text)
            }
        }
        .navigationTitle(name)
        .navigationBarTitleDisplayMode(.inline)
        .task { await load() }
        .toolbar {
            ToolbarItemGroup(placement: .topBarTrailing) {
                if hasPreview && !isLoading && loadError == nil {
                    Button {
                        editing.toggle()
                    } label: {
                        Image(systemName: editing ? "eye" : "square.and.pencil")
                    }
                }
                Button {
                    Task { await save() }
                } label: {
                    if model.isSaving { ProgressView() } else { Text("Save") }
                }
                .disabled(!isDirty || model.isSaving || isLoading)
            }
        }
    }

    private func load() async {
        isLoading = true
        loadError = nil
        do {
            let loaded = try await model.readText(path)
            text = loaded
            original = loaded
            if !seededMode {
                editing = !hasPreview  // preview by default for md/svg, edit otherwise
                seededMode = true
            }
        } catch {
            loadError = error.localizedDescription
        }
        isLoading = false
    }

    private func save() async {
        if await model.save(path: path, text: text, message: "Update \(path)") {
            original = text
        }
    }
}
