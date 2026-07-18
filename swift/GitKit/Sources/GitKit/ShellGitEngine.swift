// Depends on the subprocess-based `GitProcessRunner`, so it is macOS-only. iOS uses
// the GitHub-API transport (git-pont) behind the same `GitEngine`-shaped boundary.
#if os(macOS)
import Foundation

/// A `GitEngine` that shells out to the system `git` binary. This is the macOS
/// (Phase 1) implementation; iOS gets a `Libgit2Engine` behind the same protocol.
///
/// Ported from GitFolder's `GitSyncEngine` command sequences so behaviour matches
/// the shipping app (pull --rebase before push, `-u origin <branch>`, etc.).
public struct ShellGitEngine: GitEngine {
    private let runner: GitProcessRunner

    public init(runner: GitProcessRunner = GitProcessRunner()) {
        self.runner = runner
    }

    // MARK: GitEngine

    public func clone(_ remote: URL, to path: URL, auth: GitAuth) async throws {
        let parent = path.deletingLastPathComponent()
        try FileManager.default.createDirectory(at: parent, withIntermediateDirectories: true)
        try require(
            authArgs(auth) + ["clone", remoteString(remote), path.path],
            in: parent,
            auth: auth,
            timeout: 180,
            label: "clone"
        )
    }

    public func pullRebase(at path: URL, auth: GitAuth) async throws -> PullResult {
        let branch = try currentBranch(at: path)
        let result = try runner.run(
            authArgs(auth) + ["pull", "--rebase", "origin", branch],
            in: path,
            timeoutSeconds: 120,
            environment: authEnvironment(auth)
        )
        if result.succeeded {
            let updated = !result.standardOutput.contains("Already up to date")
            return PullResult(updated: updated, conflicts: [])
        }
        // A rebase conflict leaves unmerged paths; surface them rather than fail blindly.
        let conflicts = try unmergedPaths(at: path)
        if !conflicts.isEmpty {
            return PullResult(updated: true, conflicts: conflicts)
        }
        throw GitEngineError.commandFailed(command: "pull --rebase", exitCode: result.exitCode, stderr: result.standardError)
    }

    public func commit(at path: URL, message: String, paths: [String]) async throws {
        let addArgs = paths.isEmpty ? ["add", "-A"] : (["add", "--"] + paths)
        try require(addArgs, in: path, auth: .sshAgent, timeout: 30, label: "add")

        // If nothing is staged, `git commit` would error; report it distinctly.
        let staged = try runner.run(["diff", "--cached", "--quiet"], in: path)
        if staged.succeeded { throw GitEngineError.nothingToCommit }

        try require(["commit", "-m", message], in: path, auth: .sshAgent, timeout: 60, label: "commit")
    }

    public func push(at path: URL, auth: GitAuth) async throws {
        let branch = try currentBranch(at: path)
        try require(
            authArgs(auth) + ["push", "-u", "origin", branch],
            in: path,
            auth: auth,
            timeout: 180,
            label: "push"
        )
    }

    public func status(at path: URL) async throws -> RepoStatus {
        let porcelain = try runner.run(["status", "--porcelain"], in: path)
        guard porcelain.succeeded else {
            throw GitEngineError.commandFailed(command: "status", exitCode: porcelain.exitCode, stderr: porcelain.standardError)
        }
        let changed = porcelain.standardOutput
            .split(separator: "\n")
            .map { String($0.dropFirst(3)) }
            .filter { !$0.isEmpty }

        var ahead = 0
        var behind = 0
        // `HEAD...@{u}` with --left-right --count prints "<ahead>\t<behind>".
        let counts = try runner.run(["rev-list", "--left-right", "--count", "HEAD...@{u}"], in: path)
        if counts.succeeded {
            let parts = counts.standardOutput.split(whereSeparator: { $0 == "\t" || $0 == " " || $0 == "\n" })
            if parts.count >= 2 {
                ahead = Int(parts[0]) ?? 0
                behind = Int(parts[1]) ?? 0
            }
        }
        return RepoStatus(clean: changed.isEmpty, ahead: ahead, behind: behind, changedPaths: changed)
    }

    public func fileHistory(at path: URL, file: String, limit: Int) async throws -> [CommitInfo] {
        // Unit separator (0x1f) between fields, record separator (0x1e) between commits.
        let format = "%H\u{1f}%an\u{1f}%aI\u{1f}%s\u{1e}"
        let result = try runner.run(
            ["log", "--follow", "-n", String(limit), "--format=\(format)", "--", file],
            in: path
        )
        guard result.succeeded else {
            throw GitEngineError.commandFailed(command: "log --follow", exitCode: result.exitCode, stderr: result.standardError)
        }
        let iso = ISO8601DateFormatter()
        return result.standardOutput
            .split(separator: "\u{1e}", omittingEmptySubsequences: true)
            .compactMap { record -> CommitInfo? in
                let fields = record.split(separator: "\u{1f}", maxSplits: 3, omittingEmptySubsequences: false)
                guard fields.count == 4 else { return nil }
                let sha = fields[0].trimmingCharacters(in: .whitespacesAndNewlines)
                guard !sha.isEmpty else { return nil }
                return CommitInfo(
                    id: sha,
                    author: String(fields[1]),
                    date: iso.date(from: String(fields[2])) ?? Date(timeIntervalSince1970: 0),
                    message: String(fields[3])
                )
            }
    }

    // MARK: Helpers

    private func currentBranch(at path: URL) throws -> String {
        let result = try runner.run(["branch", "--show-current"], in: path)
        let branch = result.standardOutput.trimmingCharacters(in: .whitespacesAndNewlines)
        guard result.succeeded, !branch.isEmpty else {
            throw GitEngineError.commandFailed(command: "branch --show-current", exitCode: result.exitCode, stderr: result.standardError)
        }
        return branch
    }

    private func unmergedPaths(at path: URL) throws -> [String] {
        let result = try runner.run(["diff", "--name-only", "--diff-filter=U"], in: path)
        guard result.succeeded else { return [] }
        return result.standardOutput.split(separator: "\n").map(String.init).filter { !$0.isEmpty }
    }

    @discardableResult
    private func require(_ args: [String], in path: URL, auth: GitAuth, timeout: TimeInterval, label: String) throws -> GitCommandResult {
        let result = try runner.run(args, in: path, timeoutSeconds: timeout, environment: authEnvironment(auth))
        guard result.succeeded else {
            throw GitEngineError.commandFailed(command: label, exitCode: result.exitCode, stderr: result.standardError)
        }
        return result
    }

    /// Argument prefix that injects credentials without persisting them to config.
    private func authArgs(_ auth: GitAuth) -> [String] {
        switch auth {
        case .sshAgent:
            return []
        case let .httpsToken(username, token):
            let basic = Data("\(username):\(token)".utf8).base64EncodedString()
            return ["-c", "http.extraHeader=Authorization: Basic \(basic)"]
        }
    }

    private func authEnvironment(_ auth: GitAuth) -> [String: String] {
        switch auth {
        case .sshAgent:
            // Non-interactive: never prompt on unknown hosts or missing creds.
            return ["GIT_TERMINAL_PROMPT": "0"]
        case .httpsToken:
            return ["GIT_TERMINAL_PROMPT": "0"]
        }
    }

    private func remoteString(_ remote: URL) -> String {
        remote.isFileURL ? remote.path : remote.absoluteString
    }
}
#endif
