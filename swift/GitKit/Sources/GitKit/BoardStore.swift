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

    // MARK: Config rendering (project README)

    /// Render a full project `README.md`: a YAML frontmatter block (between `---`
    /// fences) followed by `# <name>` and the description. The frontmatter always
    /// carries `config: project` and `project:`, plus `lanes:`, `priorities:` and
    /// `users:` arrays for whichever collections are non-empty. The output is
    /// designed to parse back through `parseProjectConfig(yaml:)` unchanged.
    public static func renderProjectReadme(
        name: String,
        description: String,
        lanes: [Lane],
        priorities: [Priority],
        users: [User]
    ) -> String {
        var lines: [String] = [
            "---",
            "config: project",
            "project: \(yamlScalar(name))",
        ]

        if !lanes.isEmpty {
            lines.append("lanes:")
            for lane in lanes {
                lines.append("  - id: \(yamlScalar(lane.id))")
                lines.append("    name: \(yamlScalar(lane.name))")
                lines.append("    folder: \(yamlScalar(lane.folder))")
                lines.append("    status: \(yamlScalar(lane.status))")
                if lane.terminal == true {
                    lines.append("    terminal: true")
                }
                if lane.backlog == true {
                    lines.append("    backlog: true")
                }
            }
        }

        if !priorities.isEmpty {
            lines.append("priorities:")
            for priority in priorities {
                lines.append("  - id: \(yamlScalar(priority.id))")
                if let name = priority.name { lines.append("    name: \(yamlScalar(name))") }
                if let description = priority.description { lines.append("    description: \(yamlScalar(description))") }
            }
        }

        if !users.isEmpty {
            lines.append("users:")
            for user in users {
                lines.append("  - id: \(yamlScalar(user.id))")
                if let name = user.name { lines.append("    name: \(yamlScalar(name))") }
                if let kind = user.kind { lines.append("    kind: \(yamlScalar(kind))") }
                if let github = user.github { lines.append("    github: \(yamlScalar(github))") }
                if let role = user.role { lines.append("    role: \(yamlScalar(role))") }
            }
        }

        lines.append("---")
        let frontmatter = lines.joined(separator: "\n")
        return "\(frontmatter)\n\n# \(name)\n\n\(description)\n"
    }

    /// Render a YAML scalar, quoting when the value could be misparsed: empty
    /// strings, or any value containing spaces, colons, dots or `#`, or one that
    /// begins with a digit. Backslashes and quotes are escaped inside the quotes.
    static func yamlScalar(_ value: String) -> String {
        let needsQuote = value.isEmpty
            || value.contains(where: { $0 == " " || $0 == ":" || $0 == "." || $0 == "#" || $0 == "\"" || $0 == "'" })
            || (value.first?.isNumber ?? false)
        guard needsQuote else { return value }
        let escaped = value
            .replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "\"", with: "\\\"")
        return "\"\(escaped)\""
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
        if let oa = a.fields.order, let ob = b.fields.order, oa != ob {
            if let ia = Int(oa), let ib = Int(ob), ia != ib { return ia < ib ? -1 : 1 }
            if Int(oa) == nil || Int(ob) == nil { return oa < ob ? -1 : 1 }
        }
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
                terminal: item["terminal"] as? Bool,
                backlog: item["backlog"] as? Bool
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

    // MARK: Workspace loading ([project]/[lane]/[task] hierarchy)

    /// Load the workspace at `root`: the root config plus every project folder
    /// (an immediate subdirectory that contains a `README.md`). Projects are sorted
    /// by display name.
    public static func loadWorkspace(at root: URL) throws -> Workspace {
        let rootConfig = try loadBoardConfig(readme: root.appendingPathComponent("README.md"))

        let fm = FileManager.default
        let entries = (try? fm.contentsOfDirectory(
            at: root,
            includingPropertiesForKeys: [.isDirectoryKey],
            options: [.skipsHiddenFiles]
        )) ?? []

        var projects: [BoardProject] = []
        for entry in entries {
            let folder = entry.lastPathComponent
            guard !folder.hasPrefix("."), folder != ".git" else { continue }
            let isDirectory = (try? entry.resourceValues(forKeys: [.isDirectoryKey]))?.isDirectory ?? false
            guard isDirectory else { continue }
            let readme = entry.appendingPathComponent("README.md")
            guard fm.fileExists(atPath: readme.path) else { continue }

            let config = try loadProjectConfig(readme: readme)
            let name = config.project?.isEmpty == false ? config.project! : folder
            projects.append(BoardProject(id: folder, name: name, folder: folder, config: config))
        }

        projects.sort { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
        return Workspace(rootConfig: rootConfig, projects: projects)
    }

    /// Resolve and load a single project's board. Cards are read from each lane's
    /// folder (the lane is known from the folder, not the card `status`), and sorted
    /// within a lane the same way `columns(cards:config:)` does. Non-lane subfolders
    /// are ignored; their cards are collected into `uncategorised`.
    public static func loadProjectBoard(
        root: URL,
        project: BoardProject,
        rootConfig: BoardConfig
    ) throws -> LoadedBoard {
        let effective = resolveEffectiveConfig(rootConfig, project.config)
        let projectURL = root.appendingPathComponent(project.folder)

        var columns: [Column] = []
        var laneFolders = Set<String>()
        for lane in effective.lanes {
            laneFolders.insert(lane.folder)
            let laneURL = projectURL.appendingPathComponent(lane.folder)
            let cards: [Card]
            if FileManager.default.fileExists(atPath: laneURL.path) {
                cards = try loadCards(in: laneURL, fieldSource: effective.fieldSource)
            } else {
                cards = []
            }
            let sorted = cards.sorted { compare($0, $1, config: effective) < 0 }
            columns.append(Column(lane: lane, cards: sorted))
        }

        // Cards living in project subfolders that are not lane folders → uncategorised.
        var uncategorised: [Card] = []
        let fm = FileManager.default
        let subEntries = (try? fm.contentsOfDirectory(
            at: projectURL,
            includingPropertiesForKeys: [.isDirectoryKey],
            options: [.skipsHiddenFiles]
        )) ?? []
        for entry in subEntries {
            let folder = entry.lastPathComponent
            guard !folder.hasPrefix("."), !laneFolders.contains(folder) else { continue }
            let isDirectory = (try? entry.resourceValues(forKeys: [.isDirectoryKey]))?.isDirectory ?? false
            guard isDirectory else { continue }
            uncategorised.append(contentsOf: try loadCards(in: entry, fieldSource: effective.fieldSource))
        }

        return LoadedBoard(config: effective, columns: columns, uncategorised: uncategorised)
    }

    /// Parse a `BoardConfig` from a README's frontmatter, defaulting to empty when
    /// the file or its frontmatter is missing.
    private static func loadBoardConfig(readme: URL) throws -> BoardConfig {
        guard let text = try? String(contentsOf: readme, encoding: .utf8) else { return BoardConfig() }
        let (frontmatter, _) = BoardMarkdown.splitFrontmatter(text)
        guard let frontmatter else { return BoardConfig() }
        return try parseBoardConfig(yaml: frontmatter)
    }

    /// Parse a `ProjectConfig` from a README's frontmatter, defaulting to empty when
    /// the frontmatter is missing.
    private static func loadProjectConfig(readme: URL) throws -> ProjectConfig {
        guard let text = try? String(contentsOf: readme, encoding: .utf8) else { return ProjectConfig() }
        let (frontmatter, _) = BoardMarkdown.splitFrontmatter(text)
        guard let frontmatter else { return ProjectConfig() }
        return try parseProjectConfig(yaml: frontmatter)
    }
}

// MARK: Workspace models

/// A project discovered in a workspace: a folder under the root containing a
/// `README.md` project config.
public struct BoardProject: Identifiable, Sendable, Equatable {
    /// Folder name (also the stable identity within a workspace).
    public var id: String
    /// Display name: the project config's `project` name if present, else the folder.
    public var name: String
    /// Folder name under the workspace root.
    public var folder: String
    public var config: ProjectConfig

    public init(id: String, name: String, folder: String, config: ProjectConfig) {
        self.id = id
        self.name = name
        self.folder = folder
        self.config = config
    }
}

/// A loaded workspace: the root board config and the projects it contains.
public struct Workspace: Sendable {
    public var rootConfig: BoardConfig
    public var projects: [BoardProject]

    public init(rootConfig: BoardConfig, projects: [BoardProject]) {
        self.rootConfig = rootConfig
        self.projects = projects
    }
}

/// A single project's resolved board: its effective config plus the laid-out columns.
public struct LoadedBoard: Sendable {
    public var config: EffectiveConfig
    public var columns: [Column]
    public var uncategorised: [Card]

    public init(config: EffectiveConfig, columns: [Column], uncategorised: [Card]) {
        self.config = config
        self.columns = columns
        self.uncategorised = uncategorised
    }
}
