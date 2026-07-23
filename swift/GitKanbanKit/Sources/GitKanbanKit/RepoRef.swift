import Foundation
import GitKit

/// A config inferred from a board's folders + card fields, used to prefill the setup sheet.
public struct DetectedBoardConfig {
    public var lanes: [Lane] = []
    public var priorities: [Priority] = []
    public var users: [User] = []
    public var types: [String] = []
    public var epics: [Epic] = []

    public init(lanes: [Lane] = [], priorities: [Priority] = [], users: [User] = [],
                types: [String] = [], epics: [Epic] = []) {
        self.lanes = lanes; self.priorities = priorities; self.users = users
        self.types = types; self.epics = epics
    }
}

/// A board the user selected within a repo — a project folder path, its display name,
/// and a small summary shown in the boards list.
public struct SelectedBoard: Codable, Identifiable, Hashable {
    public var folder: String   // project folder path relative to the repo root ("" = repo root board)
    public var name: String
    public var laneCount: Int = 0
    public var memberCount: Int = 0
    public var hasBacklog: Bool = false
    public var id: String { folder }

    public init(folder: String, name: String, laneCount: Int = 0, memberCount: Int = 0, hasBacklog: Bool = false) {
        self.folder = folder; self.name = name; self.laneCount = laneCount
        self.memberCount = memberCount; self.hasBacklog = hasBacklog
    }

    public var subtitle: String {
        var parts = ["\(laneCount) lane\(laneCount == 1 ? "" : "s")"]
        if hasBacklog { parts.append("backlog") }
        if memberCount > 0 { parts.append("\(memberCount) member\(memberCount == 1 ? "" : "s")") }
        if !folder.isEmpty { parts.append(folder) }
        return parts.joined(separator: " · ")
    }
}

/// A repository the user added, plus the boards (projects) they selected from within it.
/// Persisted so the home reopens instantly without re-scanning.
public struct AddedRepo: Codable, Identifiable, Hashable {
    public var namespace: String
    public var name: String
    public var branch: String
    public var isPrivate: Bool
    public var boards: [SelectedBoard] = []

    public var fullName: String { "\(namespace)/\(name)" }
    public var id: String { fullName }
}
