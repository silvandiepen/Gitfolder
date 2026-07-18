import Foundation

/// The one thing that knows git. The apps call only this protocol, so the same UI
/// runs on macOS (shelling out to `git`) and iOS (embedded libgit2) unchanged.
///
/// See `project-assets/GitKit/GitKanban/plan/platforms-and-git.md`.
public protocol GitEngine {
    func clone(_ remote: URL, to path: URL, auth: GitAuth) async throws
    func pullRebase(at path: URL, auth: GitAuth) async throws -> PullResult
    func commit(at path: URL, message: String, paths: [String]) async throws
    func push(at path: URL, auth: GitAuth) async throws
    func status(at path: URL) async throws -> RepoStatus
    /// `git log --follow` for a single file — the per-card history view.
    func fileHistory(at path: URL, file: String, limit: Int) async throws -> [CommitInfo]
}

public extension GitEngine {
    func fileHistory(at path: URL, file: String, limit: Int = 50) async throws -> [CommitInfo] {
        try await fileHistory(at: path, file: file, limit: limit)
    }
}
