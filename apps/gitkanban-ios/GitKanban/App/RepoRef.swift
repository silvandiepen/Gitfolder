import Foundation

/// A lightweight, persistable reference to a board's repository — enough to list it and
/// rebuild the board source without a full `GitRepository`.
struct RepoRef: Codable, Identifiable, Hashable {
    var namespace: String
    var name: String
    var branch: String
    var isPrivate: Bool

    var fullName: String { "\(namespace)/\(name)" }
    var id: String { fullName }
}
