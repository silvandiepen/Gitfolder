import Foundation

/// A lightweight, persistable reference to a repository the user has added — enough to
/// list it like a folder and rebuild a `RepoFileClient` without a full `GitRepository`.
struct RepoRef: Codable, Identifiable, Hashable {
    var namespace: String
    var name: String
    var branch: String
    var isPrivate: Bool

    var fullName: String { "\(namespace)/\(name)" }
    var id: String { fullName }
}
