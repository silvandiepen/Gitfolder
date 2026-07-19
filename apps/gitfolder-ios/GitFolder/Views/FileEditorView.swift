import SwiftUI

/// View and edit a single file. Markdown files default to a rendered preview with an
/// Edit toggle; other text files open straight in the editor. Saving writes the file
/// as one commit through the provider API.
struct FileEditorView: View {
    @Environment(AppModel.self) private var model
    let path: String
    let name: String

    @State private var text = ""
    @State private var original = ""
    @State private var isLoading = true
    @State private var loadError: String?
    @State private var editing = false

    private var isMarkdown: Bool {
        let l = name.lowercased()
        return l.hasSuffix(".md") || l.hasSuffix(".markdown")
    }
    private var isDirty: Bool { text != original }

    var body: some View {
        Group {
            if isLoading {
                ProgressView()
            } else if let loadError {
                ContentUnavailableView("Couldn't open file", systemImage: "doc.badge.exclamationmark", description: Text(loadError))
            } else if editing || !isMarkdown {
                TextEditor(text: $text)
                    .font(.system(.body, design: .monospaced))
                    .autocorrectionDisabled()
                    .textInputAutocapitalization(.never)
                    .padding(.horizontal, 4)
            } else {
                ScrollView {
                    MarkdownText(text)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(16)
                }
            }
        }
        .navigationTitle(name)
        .navigationBarTitleDisplayMode(.inline)
        .task { await load() }
        .toolbar {
            ToolbarItemGroup(placement: .topBarTrailing) {
                if isMarkdown && !isLoading && loadError == nil {
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

/// A lightweight block renderer for markdown preview: headings, bullets, fenced code,
/// and paragraphs (with inline bold/italic/links/code via AttributedString).
struct MarkdownText: View {
    let source: String
    init(_ source: String) { self.source = source }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            ForEach(Array(blocks.enumerated()), id: \.offset) { _, block in
                block.view
            }
        }
    }

    private enum Block {
        case heading(String, level: Int)
        case bullet(String)
        case code(String)
        case paragraph(String)

        @ViewBuilder var view: some View {
            switch self {
            case let .heading(t, level):
                Text(t).font(level == 1 ? .title.bold() : level == 2 ? .title2.bold() : .headline)
            case let .bullet(t):
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    Text("•")
                    inline(t)
                }
            case let .code(t):
                Text(t)
                    .font(.system(.callout, design: .monospaced))
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(10)
                    .background(Color.secondary.opacity(0.12), in: RoundedRectangle(cornerRadius: 8))
            case let .paragraph(t):
                inline(t)
            }
        }

        private func inline(_ t: String) -> Text {
            if let attributed = try? AttributedString(
                markdown: t,
                options: .init(interpretedSyntax: .inlineOnlyPreservingWhitespace)
            ) {
                return Text(attributed)
            }
            return Text(t)
        }
    }

    private var blocks: [Block] {
        var result: [Block] = []
        var inCode = false
        var codeLines: [String] = []
        for line in source.components(separatedBy: "\n") {
            if line.hasPrefix("```") {
                if inCode {
                    result.append(.code(codeLines.joined(separator: "\n")))
                    codeLines = []
                }
                inCode.toggle()
                continue
            }
            if inCode { codeLines.append(line); continue }
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            if trimmed.isEmpty { continue }
            if trimmed.hasPrefix("### ") { result.append(.heading(String(trimmed.dropFirst(4)), level: 3)) }
            else if trimmed.hasPrefix("## ") { result.append(.heading(String(trimmed.dropFirst(3)), level: 2)) }
            else if trimmed.hasPrefix("# ") { result.append(.heading(String(trimmed.dropFirst(2)), level: 1)) }
            else if trimmed.hasPrefix("- ") || trimmed.hasPrefix("* ") { result.append(.bullet(String(trimmed.dropFirst(2)))) }
            else { result.append(.paragraph(trimmed)) }
        }
        if inCode && !codeLines.isEmpty { result.append(.code(codeLines.joined(separator: "\n"))) }
        return result
    }
}
