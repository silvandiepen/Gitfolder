import Foundation

/// Building and updating a card's markdown (YAML frontmatter + body). Shared so iOS
/// and macOS write byte-compatible card files. Any frontmatter key not passed is
/// preserved on update, so agent-/tool-written fields survive a round-trip.
public enum CardText {

    /// A fresh card file. Empty/nil optional fields are omitted.
    public static func make(
        id: String,
        title: String,
        project: String,
        status: String,
        priority: String? = nil,
        type: String? = nil,
        assignee: String? = nil,
        order: String? = nil,
        body: String = ""
    ) -> String {
        var lines = ["id: \(id)", "title: \(BoardStore.yamlScalar(title))"]
        if !project.isEmpty { lines.append("project: \(BoardStore.yamlScalar(project))") }
        lines.append("status: \(status)")
        if let priority, !priority.isEmpty { lines.append("priority: \(priority)") }
        if let type, !type.isEmpty { lines.append("type: \(BoardStore.yamlScalar(type))") }
        if let assignee, !assignee.isEmpty { lines.append("assignee: \(BoardStore.yamlScalar(assignee))") }
        if let order, !order.isEmpty { lines.append("order: \(order)") }
        let frontmatter = lines.joined(separator: "\n")
        let trimmed = body.trimmingCharacters(in: .whitespacesAndNewlines)
        return "---\n\(frontmatter)\n---\n\n\(trimmed)\n"
    }

    /// Update top-level frontmatter keys in `original` (a nil value removes the key),
    /// preserving unlisted keys, and optionally replace the body.
    public static func update(
        _ original: String,
        set updates: [String: String?],
        body newBody: String? = nil
    ) -> String {
        let (frontmatter, oldBody) = BoardMarkdown.splitFrontmatter(original)
        var lines = (frontmatter ?? "").components(separatedBy: "\n")
        for (key, value) in updates {
            lines = setKey(lines, key, value.flatMap { $0.isEmpty ? nil : $0 })
        }
        let frontmatter2 = lines
            .filter { !$0.trimmingCharacters(in: .whitespaces).isEmpty }
            .joined(separator: "\n")
        let body = (newBody ?? oldBody).trimmingCharacters(in: .whitespacesAndNewlines)
        return "---\n\(frontmatter2)\n---\n\n\(body)\n"
    }

    private static func setKey(_ lines: [String], _ key: String, _ value: String?) -> [String] {
        var result = lines
        let index = result.firstIndex { isTopLevelKeyLine($0, key) }
        if let value {
            let line = "\(key): \(BoardStore.yamlScalar(value))"
            if let index { result[index] = line } else { result.append(line) }
        } else if let index {
            result.remove(at: index)
        }
        return result
    }

    private static func isTopLevelKeyLine(_ line: String, _ key: String) -> Bool {
        guard let first = line.first, !first.isWhitespace else { return false }
        guard let colon = line.firstIndex(of: ":") else { return false }
        return line[line.startIndex..<colon].trimmingCharacters(in: .whitespaces) == key
    }
}
