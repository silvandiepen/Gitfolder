import Foundation

/// Swift mirror of `@gitkit/gitkanban-core`'s board schema. The TypeScript package
/// is the source of truth; these types must stay in step with it. See
/// `project-assets/Tasks/README.md` for the canonical contract.

public struct Lane: Codable, Equatable, Sendable, Identifiable {
    public var id: String
    public var name: String
    /// Directory name under the project (e.g. "1. To do"). Must exist on disk.
    public var folder: String
    /// The card `status` value this lane holds.
    public var status: String
    public var terminal: Bool?
    /// A backlog lane holds not-yet-scheduled work; it renders apart from the
    /// pipeline lanes (below the board, not as a pipeline column).
    public var backlog: Bool?

    public init(id: String, name: String, folder: String, status: String, terminal: Bool? = nil, backlog: Bool? = nil) {
        self.id = id
        self.name = name
        self.folder = folder
        self.status = status
        self.terminal = terminal
        self.backlog = backlog
    }

    /// Whether this lane is a backlog: either flagged `backlog: true` in config, or
    /// named `backlog` by convention (id or status).
    public var isBacklog: Bool {
        backlog == true || status == "backlog" || id == "backlog"
    }
}

public struct User: Codable, Equatable, Sendable {
    public var id: String
    public var name: String?
    public var kind: String?
    public var github: String?
    public var role: String?

    public init(id: String, name: String? = nil, kind: String? = nil, github: String? = nil, role: String? = nil) {
        self.id = id
        self.name = name
        self.kind = kind
        self.github = github
        self.role = role
    }
}

public struct Epic: Codable, Equatable, Sendable {
    public var id: String
    public var name: String?
    public var description: String?
    public var project: String?

    public init(id: String, name: String? = nil, description: String? = nil, project: String? = nil) {
        self.id = id
        self.name = name
        self.description = description
        self.project = project
    }
}

public struct Priority: Codable, Equatable, Sendable {
    public var id: String
    public var name: String?
    public var description: String?

    public init(id: String, name: String? = nil, description: String? = nil) {
        self.id = id
        self.name = name
        self.description = description
    }
}

/// Where a card's fields come from: YAML frontmatter (default) or a named markdown
/// body section (the legacy `audit/tasks` format).
public enum FieldSource: Equatable, Sendable {
    case frontmatter
    case bodySection(section: String?, map: [String: String])
}

/// Root board configuration.
public struct BoardConfig: Equatable, Sendable {
    public var lanes: [Lane]
    public var users: [User]
    public var epics: [Epic]
    public var priorities: [Priority]
    public var types: [String]
    public var tags: [String]
    public var fieldSource: FieldSource?

    public init(
        lanes: [Lane] = [],
        users: [User] = [],
        epics: [Epic] = [],
        priorities: [Priority] = [],
        types: [String] = [],
        tags: [String] = [],
        fieldSource: FieldSource? = nil
    ) {
        self.lanes = lanes
        self.users = users
        self.epics = epics
        self.priorities = priorities
        self.types = types
        self.tags = tags
        self.fieldSource = fieldSource
    }
}

/// Per-project configuration overlaid on the root.
public struct ProjectConfig: Equatable, Sendable {
    public var project: String?
    public var lanes: [Lane]?
    public var users: [User]?
    public var epics: [Epic]?
    public var priorities: [Priority]?
    public var types: [String]?
    public var tags: [String]?
    public var fieldSource: FieldSource?

    public init(
        project: String? = nil,
        lanes: [Lane]? = nil,
        users: [User]? = nil,
        epics: [Epic]? = nil,
        priorities: [Priority]? = nil,
        types: [String]? = nil,
        tags: [String]? = nil,
        fieldSource: FieldSource? = nil
    ) {
        self.project = project
        self.lanes = lanes
        self.users = users
        self.epics = epics
        self.priorities = priorities
        self.types = types
        self.tags = tags
        self.fieldSource = fieldSource
    }
}

/// The resolved configuration a board is rendered from.
public struct EffectiveConfig: Equatable, Sendable {
    public var project: String?
    public var lanes: [Lane]
    public var users: [User]
    public var epics: [Epic]
    public var priorities: [Priority]
    public var types: [String]
    public var tags: [String]
    public var fieldSource: FieldSource?

    public init(
        project: String? = nil,
        lanes: [Lane] = [],
        users: [User] = [],
        epics: [Epic] = [],
        priorities: [Priority] = [],
        types: [String] = [],
        tags: [String] = [],
        fieldSource: FieldSource? = nil
    ) {
        self.project = project
        self.lanes = lanes
        self.users = users
        self.epics = epics
        self.priorities = priorities
        self.types = types
        self.tags = tags
        self.fieldSource = fieldSource
    }
}

/// The fields GitKanban models on a card. Unknown frontmatter is preserved on `Card`.
public struct CardFields: Equatable, Sendable {
    public var id: String
    public var title: String
    public var project: String
    public var status: String
    public var priority: String?
    public var type: String?
    public var epic: String?
    public var assignee: String?
    public var order: String?

    public init(
        id: String = "", title: String = "", project: String = "", status: String = "",
        priority: String? = nil, type: String? = nil, epic: String? = nil,
        assignee: String? = nil, order: String? = nil
    ) {
        self.id = id
        self.title = title
        self.project = project
        self.status = status
        self.priority = priority
        self.type = type
        self.epic = epic
        self.assignee = assignee
        self.order = order
    }
}

/// A card resolved for display: its modelled fields plus the markdown body.
/// (Full frontmatter round-tripping for the editor is a later ticket; the board
/// renders from `fields`.)
public struct Card: Equatable, Sendable, Identifiable {
    public var fields: CardFields
    public var body: String
    /// File name on disk, when loaded from a folder.
    public var fileName: String?

    public var id: String { !fields.id.isEmpty ? fields.id : (fileName ?? fields.title) }

    public init(fields: CardFields, body: String, fileName: String? = nil) {
        self.fields = fields
        self.body = body
        self.fileName = fileName
    }
}

/// A board column: a lane and the cards currently in it, in display order.
public struct Column: Equatable, Sendable, Identifiable {
    public var lane: Lane
    public var cards: [Card]
    public var id: String { lane.id }

    public init(lane: Lane, cards: [Card]) {
        self.lane = lane
        self.cards = cards
    }
}
