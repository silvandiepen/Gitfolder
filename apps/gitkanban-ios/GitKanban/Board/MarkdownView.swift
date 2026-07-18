import SwiftUI

/// A lightweight native Markdown renderer for card descriptions: headings, bullet and
/// numbered lists, block quotes, fenced code, and paragraphs — with inline **bold**,
/// *italic*, `code`, and [links] rendered via `AttributedString`. Kept dependency-free
/// (no WebView) so it stays snappy inside a sheet.
struct MarkdownView: View {
    let text: String

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            ForEach(Array(Self.parse(text).enumerated()), id: \.offset) { _, block in
                block.view
            }
        }
    }

    // MARK: Blocks

    enum Block {
        case heading(level: Int, text: String)
        case paragraph(String)
        case bullets([String])
        case numbered([String])
        case quote(String)
        case code(String)

        @ViewBuilder var view: some View {
            switch self {
            case let .heading(level, text):
                MarkdownView.inline(text)
                    .font(headingFont(level))
                    .fontWeight(.semibold)
                    .padding(.top, level <= 2 ? 4 : 0)
            case let .paragraph(text):
                MarkdownView.inline(text)
                    .font(.body)
                    .fixedSize(horizontal: false, vertical: true)
            case let .bullets(items):
                VStack(alignment: .leading, spacing: 4) {
                    ForEach(Array(items.enumerated()), id: \.offset) { _, item in
                        HStack(alignment: .firstTextBaseline, spacing: 8) {
                            Text("•").foregroundStyle(.secondary)
                            MarkdownView.inline(item).font(.body).fixedSize(horizontal: false, vertical: true)
                        }
                    }
                }
            case let .numbered(items):
                VStack(alignment: .leading, spacing: 4) {
                    ForEach(Array(items.enumerated()), id: \.offset) { index, item in
                        HStack(alignment: .firstTextBaseline, spacing: 8) {
                            Text("\(index + 1).").foregroundStyle(.secondary).monospacedDigit()
                            MarkdownView.inline(item).font(.body).fixedSize(horizontal: false, vertical: true)
                        }
                    }
                }
            case let .quote(text):
                HStack(spacing: 8) {
                    Rectangle().fill(.tertiary).frame(width: 3)
                    MarkdownView.inline(text).font(.body).foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            case let .code(code):
                ScrollView(.horizontal, showsIndicators: false) {
                    Text(code)
                        .font(.system(.callout, design: .monospaced))
                        .padding(10)
                }
                .background(.quaternary.opacity(0.4), in: RoundedRectangle(cornerRadius: 8))
            }
        }

        private func headingFont(_ level: Int) -> Font {
            switch level {
            case 1: return .title2
            case 2: return .title3
            default: return .headline
            }
        }
    }

    /// Render inline markdown (bold/italic/code/links) within one line.
    static func inline(_ string: String) -> Text {
        if let attributed = try? AttributedString(
            markdown: string,
            options: .init(interpretedSyntax: .inlineOnlyPreservingWhitespace)
        ) {
            return Text(attributed)
        }
        return Text(string)
    }

    // MARK: Parser

    static func parse(_ text: String) -> [Block] {
        var blocks: [Block] = []
        let lines = text.components(separatedBy: "\n")
        var i = 0

        func flushParagraph(_ buffer: inout [String]) {
            if !buffer.isEmpty {
                blocks.append(.paragraph(buffer.joined(separator: " ")))
                buffer.removeAll()
            }
        }

        var paragraph: [String] = []
        while i < lines.count {
            let line = lines[i]
            let trimmed = line.trimmingCharacters(in: .whitespaces)

            // Fenced code block.
            if trimmed.hasPrefix("```") {
                flushParagraph(&paragraph)
                var code: [String] = []
                i += 1
                while i < lines.count, !lines[i].trimmingCharacters(in: .whitespaces).hasPrefix("```") {
                    code.append(lines[i]); i += 1
                }
                i += 1 // closing fence
                blocks.append(.code(code.joined(separator: "\n")))
                continue
            }

            if trimmed.isEmpty {
                flushParagraph(&paragraph)
                i += 1
                continue
            }

            // Heading.
            if let hashes = trimmed.range(of: "^#{1,6} ", options: .regularExpression) {
                flushParagraph(&paragraph)
                let level = trimmed.distance(from: trimmed.startIndex, to: hashes.upperBound) - 1
                let content = String(trimmed[hashes.upperBound...])
                blocks.append(.heading(level: level, text: content))
                i += 1
                continue
            }

            // Bullet list (consecutive).
            if trimmed.range(of: "^[-*] ", options: .regularExpression) != nil {
                flushParagraph(&paragraph)
                var items: [String] = []
                while i < lines.count,
                      let r = lines[i].trimmingCharacters(in: .whitespaces).range(of: "^[-*] ", options: .regularExpression) {
                    let t = lines[i].trimmingCharacters(in: .whitespaces)
                    items.append(String(t[r.upperBound...]))
                    i += 1
                }
                blocks.append(.bullets(items))
                continue
            }

            // Numbered list (consecutive).
            if trimmed.range(of: "^\\d+\\. ", options: .regularExpression) != nil {
                flushParagraph(&paragraph)
                var items: [String] = []
                while i < lines.count,
                      let r = lines[i].trimmingCharacters(in: .whitespaces).range(of: "^\\d+\\. ", options: .regularExpression) {
                    let t = lines[i].trimmingCharacters(in: .whitespaces)
                    items.append(String(t[r.upperBound...]))
                    i += 1
                }
                blocks.append(.numbered(items))
                continue
            }

            // Block quote.
            if trimmed.hasPrefix("> ") {
                flushParagraph(&paragraph)
                blocks.append(.quote(String(trimmed.dropFirst(2))))
                i += 1
                continue
            }

            paragraph.append(trimmed)
            i += 1
        }
        flushParagraph(&paragraph)
        return blocks
    }
}
