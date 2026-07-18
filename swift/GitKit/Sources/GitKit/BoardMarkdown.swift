import Foundation

/// String helpers for reading card fields out of markdown, mirroring
/// `@gitkit/gitkanban-core`'s `bodyfields.ts`. Pure (no YAML) so they are simple
/// and portable.
public enum BoardMarkdown {
    /// Split a document into its raw YAML frontmatter string and its body.
    /// Returns `nil` frontmatter when there is no leading `---` block.
    public static func splitFrontmatter(_ text: String) -> (frontmatter: String?, body: String) {
        guard text.hasPrefix("---") else { return (nil, text) }
        // Find the closing delimiter line.
        let lines = text.components(separatedBy: "\n")
        guard lines.first == "---" || lines.first?.trimmingCharacters(in: .whitespaces) == "---" else {
            return (nil, text)
        }
        var closingIndex: Int?
        for index in 1..<lines.count where lines[index].trimmingCharacters(in: .whitespaces) == "---" {
            closingIndex = index
            break
        }
        guard let close = closingIndex else { return (nil, text) }
        let yaml = lines[1..<close].joined(separator: "\n")
        let body = lines[(close + 1)...].joined(separator: "\n")
        return (yaml, body)
    }

    /// The first `# H1` line, without the leading `# `.
    public static func extractTitle(_ body: String) -> String {
        for line in body.components(separatedBy: "\n") {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            if trimmed.hasPrefix("# ") {
                return String(trimmed.dropFirst(2)).trimmingCharacters(in: .whitespaces)
            }
        }
        return ""
    }

    /// The text of a markdown section by heading name, up to the next heading.
    public static func extractSection(_ body: String, _ section: String) -> String {
        let lines = body.components(separatedBy: "\n")
        var start: Int?
        for (index, line) in lines.enumerated() {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            if isHeading(trimmed), headingText(trimmed) == section {
                start = index + 1
                break
            }
        }
        guard let begin = start else { return "" }
        var end = lines.count
        for index in begin..<lines.count where isHeading(lines[index].trimmingCharacters(in: .whitespaces)) {
            end = index
            break
        }
        return lines[begin..<end].joined(separator: "\n")
    }

    /// The value after a bold `**Label:**` (optionally a `- ` list item, colon inside
    /// or outside the bold). Returns nil for absent or placeholder (`—`, `-`, empty…).
    public static func extractLabeledValue(_ text: String, _ label: String) -> String? {
        let pattern = "\\*\\*\\s*\(NSRegularExpression.escapedPattern(for: label))\\s*:?\\s*\\*\\*\\s*:?\\s*(.*)"
        guard let re = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]) else { return nil }
        let range = NSRange(text.startIndex..<text.endIndex, in: text)
        guard let match = re.firstMatch(in: text, range: range), match.numberOfRanges >= 2,
              let valueRange = Range(match.range(at: 1), in: text) else { return nil }
        return normalizeValue(String(text[valueRange]))
    }

    /// Parse an audit-task filename `P{n}-{CAT}-{NNNN}-{slug}.md`.
    public static func parseAuditFilename(_ filename: String) -> (priority: String, id: String, slug: String)? {
        let base = filename.hasSuffix(".md") ? String(filename.dropLast(3)) : filename
        guard let re = try? NSRegularExpression(pattern: "^(P\\d+)-([A-Z0-9]+-\\d+)-(.+)$") else { return nil }
        let range = NSRange(base.startIndex..<base.endIndex, in: base)
        guard let m = re.firstMatch(in: base, range: range), m.numberOfRanges == 4,
              let p = Range(m.range(at: 1), in: base),
              let i = Range(m.range(at: 2), in: base),
              let s = Range(m.range(at: 3), in: base) else { return nil }
        return (String(base[p]), String(base[i]), String(base[s]))
    }

    private static func normalizeValue(_ raw: String) -> String? {
        let value = raw.replacingOccurrences(of: "`", with: "").trimmingCharacters(in: .whitespacesAndNewlines)
        if value.isEmpty || value == "—" || value == "-" { return nil }
        if ["none", "n/a", "tbd"].contains(value.lowercased()) { return nil }
        return value
    }

    private static func isHeading(_ trimmed: String) -> Bool {
        var hashes = 0
        for character in trimmed { if character == "#" { hashes += 1 } else { break } }
        return hashes >= 1 && hashes <= 6 && trimmed.dropFirst(hashes).first == " "
    }

    private static func headingText(_ trimmed: String) -> String {
        String(trimmed.drop(while: { $0 == "#" })).trimmingCharacters(in: .whitespaces)
    }
}
