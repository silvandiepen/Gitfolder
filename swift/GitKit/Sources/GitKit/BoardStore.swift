import Foundation
import Yams

/// Parsing board configuration and cards from markdown/YAML, and assembling a
/// board's columns. Mirrors the read path of `@gitkit/gitkanban-core`.
public enum BoardStore {

    // MARK: Config parsing (from a README's YAML frontmatter)

    /// Parse a root `BoardConfig` from a YAML string (a `Tasks/README.md` frontmatter).
    public static func parseBoardConfig(yaml: String) throws -> BoardConfig {
        let map = try dictionary(from: yaml)
        return BoardConfig(
            lanes: lanes(from: map["lanes"]),
            users: users(from: map["users"]),
            epics: epics(from: map["epics"]),
            priorities: priorities(from: map["priorities"]),
            types: strings(from: map["types"]),
            tags: strings(from: map["tags"]),
            fieldSource: fieldSource(from: map["fieldSource"])
        )
    }

    /// Parse a `ProjectConfig` from a YAML string (a `Tasks/<project>/README.md` frontmatter).
    public static func parseProjectConfig(yaml: String) throws -> ProjectConfig {
        let map = try dictionary(from: yaml)
        let laneList = map["lanes"].map { lanes(from: $0) }
        return ProjectConfig(
            project: map["project"] as? String,
            lanes: laneList,
            users: map["users"].map { users(from: $0) },
            epics: map["epics"].map { epics(from: $0) },
            priorities: map["priorities"].map { priorities(from: $0) },
            types: map["types"].map { strings(from: $0) },
            tags: map["tags"].map { strings(from: $0) },
            fieldSource: fieldSource(from: map["fieldSource"])
        )
    }

    // MARK: Card parsing

    /// Parse a single card's text into a display `Card`, honouring the field source.
    /// `fileName` supplies id/priority for body-section boards (audit filenames).
    public static func parseCard(text: String, fileName: String? = nil, fieldSource: FieldSource?) -> Card {
        let (frontmatter, body) = BoardMarkdown.splitFrontmatter(text)
        let fields: CardFields
        switch fieldSource {
        case let .bodySection(section, labelMap):
            fields = bodySectionFields(body: body, section: section, map: labelMap, fileName: fileName)
        default:
            fields = frontmatterFields(frontmatter, fileName: fileName)
        }
        return Card(fields: fields, body: body, fileName: fileName)
    }

    private static func frontmatterFields(_ yaml: String?, fileName: String?) -> CardFields {
        let map = (yaml.flatMap { try? dictionary(from: $0) }) ?? [:]
        func str(_ key: String) -> String? {
            if let value = map[key] as? String { return value }
            if let value = map[key] { return String(describing: value) }
            return nil
        }
        return CardFields(
            id: str("id") ?? "",
            title: str("title") ?? "",
            project: str("project") ?? "",
            status: str("status") ?? "",
            priority: nonEmpty(str("priority")),
            type: nonEmpty(str("type")),
            epic: nonEmpty(str("epic")),
            assignee: nonEmpty(str("assignee")),
            order: nonEmpty(str("order"))
        )
    }

    private static func bodySectionFields(body: String, section: String?, map: [String: String], fileName: String?) -> CardFields {
        let sectionText = section.map { BoardMarkdown.extractSection(body, $0) } ?? ""
        func value(_ field: String) -> String? {
            guard let label = map[field] else { return nil }
            return BoardMarkdown.extractLabeledValue(sectionText, label)
                ?? BoardMarkdown.extractLabeledValue(body, label)
        }
        let parsedName = fileName.flatMap { BoardMarkdown.parseAuditFilename($0) }
        return CardFields(
            id: value("id") ?? parsedName?.id ?? "",
            title: value("title") ?? BoardMarkdown.extractTitle(body),
            project: value("project") ?? "",
            status: value("status") ?? "",
            priority: value("priority") ?? parsedName?.priority,
            type: value("type"),
            epic: value("epic"),
            assignee: value("assignee"),
            order: nil
        )
    }

    // MARK: Loading + grouping

    /// Load every card file in a folder (skipping README/index files).
    public static func loadCards(in folder: URL, fieldSource: FieldSource?) throws -> [Card] {
        let names = try FileManager.default.contentsOfDirectory(atPath: folder.path)
        return try names
            .filter { $0.hasSuffix(".md") && $0 != "README.md" && !$0.hasPrefix("00-") }
            .sorted()
            .map { name in
                let text = try String(contentsOf: folder.appendingPathComponent(name), encoding: .utf8)
                return parseCard(text: text, fileName: name, fieldSource: fieldSource)
            }
    }

    /// Group cards into columns in lane order; cards whose status matches no lane
    /// are returned in `uncategorised` rather than dropped.
    public static func columns(cards: [Card], config: EffectiveConfig) -> (columns: [Column], uncategorised: [Card]) {
        var buckets: [String: [Card]] = [:]
        var uncategorised: [Card] = []
        let laneStatuses = Set(config.lanes.map(\.status))
        for card in cards {
            if laneStatuses.contains(card.fields.status) {
                buckets[card.fields.status, default: []].append(card)
            } else {
                uncategorised.append(card)
            }
        }
        let columns = config.lanes.map { lane in
            Column(lane: lane, cards: (buckets[lane.status] ?? []).sorted { lhs, rhs in
                compare(lhs, rhs, config: config) < 0
            })
        }
        return (columns, uncategorised)
    }

    private static func compare(_ a: Card, _ b: Card, config: EffectiveConfig) -> Int {
        if let oa = a.fields.order, let ob = b.fields.order, oa != ob { return oa < ob ? -1 : 1 }
        let pa = priorityRank(a.fields.priority, config)
        let pb = priorityRank(b.fields.priority, config)
        if pa != pb { return pa - pb }
        return a.fields.id < b.fields.id ? -1 : (a.fields.id > b.fields.id ? 1 : 0)
    }

    private static func priorityRank(_ priority: String?, _ config: EffectiveConfig) -> Int {
        guard let priority else { return config.priorities.count }
        let index = config.priorities.firstIndex { $0.id == priority }
        return index ?? config.priorities.count
    }

    // MARK: YAML helpers

    private static func dictionary(from yaml: String) throws -> [String: Any] {
        guard !yaml.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return [:] }
        return (try Yams.load(yaml: yaml)) as? [String: Any] ?? [:]
    }

    private static func nonEmpty(_ value: String?) -> String? {
        guard let value, !value.isEmpty, value != "null" else { return nil }
        return value
    }

    private static func lanes(from value: Any?) -> [Lane] {
        (value as? [[String: Any]] ?? []).compactMap { item in
            guard let id = item["id"] as? String, let status = item["status"] as? String else { return nil }
            return Lane(
                id: id,
                name: item["name"] as? String ?? id,
                folder: item["folder"] as? String ?? "",
                status: status,
                terminal: item["terminal"] as? Bool
            )
        }
    }

    private static func users(from value: Any?) -> [User] {
        (value as? [[String: Any]] ?? []).compactMap { item in
            guard let id = item["id"] as? String else { return nil }
            return User(
                id: id,
                name: item["name"] as? String,
                kind: item["kind"] as? String,
                github: item["github"] as? String,
                role: item["role"] as? String
            )
        }
    }

    private static func epics(from value: Any?) -> [Epic] {
        (value as? [[String: Any]] ?? []).compactMap { item in
            guard let id = item["id"] as? String else { return nil }
            return Epic(id: id, name: item["name"] as? String, description: item["description"] as? String, project: item["project"] as? String)
        }
    }

    private static func priorities(from value: Any?) -> [Priority] {
        (value as? [[String: Any]] ?? []).compactMap { item in
            guard let id = item["id"] as? String else { return nil }
            return Priority(id: id, name: item["name"] as? String, description: item["description"] as? String)
        }
    }

    private static func strings(from value: Any?) -> [String] {
        (value as? [Any] ?? []).compactMap { $0 as? String }
    }

    private static func fieldSource(from value: Any?) -> FieldSource? {
        guard let map = value as? [String: Any], let mode = map["mode"] as? String else { return nil }
        if mode == "body-section" {
            let labelMap = (map["map"] as? [String: Any] ?? [:]).compactMapValues { $0 as? String }
            return .bodySection(section: map["section"] as? String, map: labelMap)
        }
        return .frontmatter
    }
}
