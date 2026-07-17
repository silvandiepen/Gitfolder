import Foundation

/// How to authenticate to the remote. macOS can use SSH or an HTTPS token; iOS uses
/// an HTTPS token (no SSH agent). See the platforms-and-git plan doc.
public enum GitAuth {
    case sshAgent
    case httpsToken(username: String, token: String)
}

public struct PullResult: Sendable {
    public let updated: Bool
    public let conflicts: [String]
    public init(updated: Bool, conflicts: [String] = []) {
        self.updated = updated
        self.conflicts = conflicts
    }
}

public struct RepoStatus: Sendable {
    public let clean: Bool
    public let ahead: Int
    public let behind: Int
    public let changedPaths: [String]
    public init(clean: Bool, ahead: Int, behind: Int, changedPaths: [String]) {
        self.clean = clean
        self.ahead = ahead
        self.behind = behind
        self.changedPaths = changedPaths
    }
}

public struct CommitInfo: Sendable, Identifiable {
    public let id: String        // sha
    public let author: String
    public let date: Date
    public let message: String
    public init(id: String, author: String, date: Date, message: String) {
        self.id = id
        self.author = author
        self.date = date
        self.message = message
    }
}
