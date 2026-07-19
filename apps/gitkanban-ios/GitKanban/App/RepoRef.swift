import Foundation
import GitKit

/// A config inferred from a board's folders + card fields, used to prefill the setup sheet.
struct DetectedBoardConfig {
    var lanes: [Lane] = []
    var priorities: [Priority] = []
    var users: [User] = []
    var types: [String] = []
    var epics: [Epic] = []
}

/// A board the user selected within a repo — a project folder path, its display name,
/// and a small summary shown in the boards list.
struct SelectedBoard: Codable, Identifiable, Hashable {
    var folder: String   // project folder path relative to the repo root ("" = repo root board)
    var name: String
    var laneCount: Int = 0
    var memberCount: Int = 0
    var hasBacklog: Bool = false
    var id: String { folder }

    var subtitle: String {
        var parts = ["\(laneCount) lane\(laneCount == 1 ? "" : "s")"]
        if hasBacklog { parts.append("backlog") }
        if memberCount > 0 { parts.append("\(memberCount) member\(memberCount == 1 ? "" : "s")") }
        if !folder.isEmpty { parts.append(folder) }
        return parts.joined(separator: " · ")
    }
}

/// A repository the user added, plus the boards (projects) they selected from within it.
/// Persisted so the home reopens instantly without re-scanning.
struct AddedRepo: Codable, Identifiable, Hashable {
    var namespace: String
    var name: String
    var branch: String
    var isPrivate: Bool
    var boards: [SelectedBoard] = []

    var fullName: String { "\(namespace)/\(name)" }
    var id: String { fullName }
}
