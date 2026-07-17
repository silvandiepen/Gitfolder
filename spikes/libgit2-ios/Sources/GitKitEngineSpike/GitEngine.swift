import Foundation

// The durable artifact of this spike is this protocol, not the SwiftGit2 code below.
// It is the iOS-side view of the shared `GitEngine` the other session is defining in
// GITKIT-006 (ShellGitEngine, macOS). Keep this in sync with that definition — when the
// shared `swift/GitKit` package (GITKIT-005) lands, delete this copy and conform the real
// Libgit2Engine to the package's protocol. The point of the spike is to confirm every
// requirement below is satisfiable with libgit2 over HTTPS on iOS.

/// Credentials for an HTTPS git remote. iOS has no ssh-agent and no shell, so token-over-HTTPS
/// is the only viable transport (GitHub accepts `x-access-token:<token>` as basic auth).
public struct GitCredentials: Sendable {
    public var username: String
    public var token: String
    public init(username: String = "x-access-token", token: String) {
        self.username = username
        self.token = token
    }
}

public struct CommitResult: Sendable, Equatable {
    public var sha: String
    public var message: String
}

/// Minimal engine surface the iOS app needs. macOS satisfies the same protocol with a
/// subprocess engine; iOS satisfies it with libgit2. The app layer must not care which.
public protocol GitEngine: Sendable {
    /// Clone `remoteURL` into `directory` over HTTPS using `credentials`. Must work for a fresh
    /// clone into the app container and be cancellable/progress-reportable in the real engine.
    func clone(from remoteURL: URL, into directory: URL, credentials: GitCredentials) async throws

    /// Stage all changes and create a snapshot commit. Returns the new commit.
    func commitAll(in directory: URL, message: String, author: Signature) async throws -> CommitResult

    /// Integrate remote changes before pushing (fetch + rebase/merge). Must surface conflicts
    /// as `GitEngineError.conflict` and leave the working tree clean — never mid-rebase
    /// (this is the iOS mirror of audit finding EXP-0002 / card GITKIT-013).
    func pullRebase(in directory: URL, branch: String, credentials: GitCredentials) async throws

    /// Push `branch` to origin over HTTPS. The make-or-break capability for the spike.
    func push(in directory: URL, branch: String, credentials: GitCredentials) async throws
}

public struct Signature: Sendable, Equatable {
    public var name: String
    public var email: String
    public init(name: String, email: String) { self.name = name; self.email = email }
}

public enum GitEngineError: Error, Sendable {
    case cloneFailed(String)
    case commitFailed(String)
    case pushFailed(String)
    /// Pull produced a conflict. The engine MUST have already aborted back to a clean tree.
    case conflict(String)
    case authFailed(String)
    case notImplemented(String)
}
