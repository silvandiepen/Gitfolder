import Foundation

/// A lightweight, persistable reference to a board's repository — enough to list it and
/// rebuild the board source without a full `GitRepository`.
struct RepoRef: Codable, Identifiable, Hashable {
    var namespace: String
    var name: String
    var branch: String
    var isPrivate: Bool
    /// Optional subfolder within the repo where the boards live (e.g. "project-assets/Tasks").
    var path: String = ""

    var fullName: String { "\(namespace)/\(name)" }
    /// Distinct per repo + subpath, so the same repo can be added at different paths.
    var id: String { path.isEmpty ? fullName : "\(fullName)#\(path)" }
    /// A short label for the board's location.
    var displayName: String { path.isEmpty ? name : "\(name)/\(path)" }
}
