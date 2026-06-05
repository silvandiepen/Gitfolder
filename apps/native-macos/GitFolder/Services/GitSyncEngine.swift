import Foundation

struct FolderSyncOutcome: Equatable, Sendable {
    var folder: SyncedFolder
    var changed: Bool
    var pushed: Bool
    var message: String
}

struct GitSyncOptions: Equatable, Sendable {
    var gitAuthorName: String?
    var gitAuthorEmail: String?
    var sshPrivateKeyPath: String?
    var sshPrivateKeyBookmarkData: Data?

    static let defaults = GitSyncOptions(
        gitAuthorName: nil,
        gitAuthorEmail: nil,
        sshPrivateKeyPath: nil,
        sshPrivateKeyBookmarkData: nil
    )
}

struct GitSyncEngine: Sendable {
    private let gitRunner: GitRunner
    private let folderAccessService: FolderAccessService
    private let now: @Sendable () -> Date

    init(
        gitRunner: GitRunner = GitRunner(),
        folderAccessService: FolderAccessService = FolderAccessService(),
        now: @escaping @Sendable () -> Date = { Date() }
    ) {
        self.gitRunner = gitRunner
        self.folderAccessService = folderAccessService
        self.now = now
    }

    func sync(_ folder: SyncedFolder, options: GitSyncOptions = .defaults) async throws -> FolderSyncOutcome {
        try await Task.detached(priority: .utility) {
            try self.syncSynchronously(folder, options: options)
        }.value
    }

    private func syncSynchronously(_ folder: SyncedFolder, options: GitSyncOptions) throws -> FolderSyncOutcome {
        guard folder.enabled else {
            return FolderSyncOutcome(folder: folder.marked(status: .paused, message: nil, at: now()), changed: false, pushed: false, message: "Folder is paused")
        }

        guard !folder.repoUrl.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw GitSyncError.missingRepositoryURL
        }

        return try folderAccessService.withSecurityScopedAccess(for: folder) { folderURL in
            let sshKeyAccess = try startSSHKeyAccess(options)
            defer { sshKeyAccess.stop() }
            let environment = gitEnvironment(sshKeyURL: sshKeyAccess.url)

            guard FileManager.default.fileExists(atPath: folderURL.path) else {
                throw GitSyncError.folderMissing(folderURL.path)
            }

            var updatedFolder = folder
            updatedFolder.localPath = folderURL.path
            updatedFolder.lastCheckedAt = now()
            updatedFolder.lastSyncAt = now()
            updatedFolder.lastError = nil

            try ensureRepository(in: folderURL, folder: updatedFolder, options: options, environment: environment)
            try ensureRemote(in: folderURL, repoUrl: updatedFolder.repoUrl, environment: environment)
            try ensureBranch(in: folderURL, branch: updatedFolder.branch, environment: environment)

            let status = try requireSuccess(git(["status", "--porcelain"], in: folderURL, environment: environment), failure: .gitStatusFailed())
            guard !status.standardOutput.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
                updatedFolder.lastSuccessfulSyncAt = now()
                updatedFolder.updatedAt = now()
                updatedFolder.lastStatus = .synced
                return FolderSyncOutcome(folder: updatedFolder, changed: false, pushed: false, message: "No changes")
            }

            _ = try requireSuccess(git(["add", "-A"], in: folderURL, environment: environment), failure: .gitAddFailed())

            let commitMessage = SnapshotCommitMessage.make(date: now())
            let commit = git(["commit", "-m", commitMessage], in: folderURL, timeoutSeconds: 60, environment: environment)
            if !commit.succeeded {
                if commit.combinedOutput.localizedCaseInsensitiveContains("nothing to commit") {
                    updatedFolder.lastSuccessfulSyncAt = now()
                    updatedFolder.updatedAt = now()
                    updatedFolder.lastStatus = .synced
                    return FolderSyncOutcome(folder: updatedFolder, changed: false, pushed: false, message: "No changes")
                }
                throw GitSyncError.gitCommitFailed(commit.combinedOutput)
            }

            let pull = git(["pull", "--rebase", "origin", updatedFolder.branch], in: folderURL, timeoutSeconds: 120, environment: environment)
            if !pull.succeeded && !isMissingUpstreamOutput(pull.combinedOutput) {
                throw GitSyncError.pullRebaseFailed(pull.combinedOutput)
            }

            let push = git(["push", "-u", "origin", updatedFolder.branch], in: folderURL, timeoutSeconds: 180, environment: environment)
            guard push.succeeded else {
                throw GitSyncError.gitPushFailed(push.combinedOutput)
            }

            updatedFolder.lastSuccessfulSyncAt = now()
            updatedFolder.updatedAt = now()
            updatedFolder.lastStatus = .synced
            return FolderSyncOutcome(folder: updatedFolder, changed: true, pushed: true, message: "Committed and pushed")
        }
    }

    private func ensureRepository(in folderURL: URL, folder: SyncedFolder, options: GitSyncOptions, environment: [String: String]) throws {
        let gitDirectory = folderURL.appending(path: ".git", directoryHint: .isDirectory)
        if !FileManager.default.fileExists(atPath: gitDirectory.path) {
            _ = try requireSuccess(git(["init"], in: folderURL, environment: environment), failure: .gitInitFailed())
        }

        if let authorName = nonEmpty(options.gitAuthorName) {
            _ = try requireSuccess(git(["config", "user.name", authorName], in: folderURL, environment: environment), failure: .gitConfigFailed("Could not save Git author name for this folder."))
        }
        if let authorEmail = nonEmpty(options.gitAuthorEmail) {
            _ = try requireSuccess(git(["config", "user.email", authorEmail], in: folderURL, environment: environment), failure: .gitConfigFailed("Could not save Git author email for this folder."))
        }

        _ = try requireSuccess(git(["config", "user.name"], in: folderURL, environment: environment), failure: .gitConfigFailed("Missing Git user.name. Add a Git author name in GitFolder Settings or configure Git globally."))
        _ = try requireSuccess(git(["config", "user.email"], in: folderURL, environment: environment), failure: .gitConfigFailed("Missing Git user.email. Add a Git author email in GitFolder Settings or configure Git globally."))
    }

    private func ensureRemote(in folderURL: URL, repoUrl: String, environment: [String: String]) throws {
        let currentRemote = git(["remote", "get-url", "origin"], in: folderURL, environment: environment)
        if currentRemote.succeeded {
            let existing = currentRemote.standardOutput.trimmingCharacters(in: .whitespacesAndNewlines)
            guard existing == repoUrl else {
                _ = try requireSuccess(git(["remote", "set-url", "origin", repoUrl], in: folderURL, environment: environment), failure: .gitRemoteFailed())
                return
            }
            return
        }

        _ = try requireSuccess(git(["remote", "add", "origin", repoUrl], in: folderURL, environment: environment), failure: .gitRemoteFailed())
    }

    private func ensureBranch(in folderURL: URL, branch: String, environment: [String: String]) throws {
        let branchName = branch.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "main" : branch
        let currentBranch = git(["branch", "--show-current"], in: folderURL, environment: environment)
        if currentBranch.succeeded, currentBranch.standardOutput.trimmingCharacters(in: .whitespacesAndNewlines) == branchName {
            return
        }

        let checkoutExisting = git(["checkout", branchName], in: folderURL, environment: environment)
        if checkoutExisting.succeeded { return }

        _ = try requireSuccess(git(["checkout", "-B", branchName], in: folderURL, environment: environment), failure: .gitCheckoutFailed())
    }

    private func git(_ arguments: [String], in workingDirectory: URL, timeoutSeconds: TimeInterval = 30, environment: [String: String] = [:]) -> GitCommandResult {
        do {
            return try gitRunner.run(arguments, in: workingDirectory, timeoutSeconds: timeoutSeconds, environment: environment)
        } catch {
            return GitCommandResult(exitCode: 1, standardOutput: "", standardError: error.localizedDescription)
        }
    }

    private func startSSHKeyAccess(_ options: GitSyncOptions) throws -> ScopedURLAccess {
        guard let bookmarkData = options.sshPrivateKeyBookmarkData else {
            if let path = nonEmpty(options.sshPrivateKeyPath) {
                return ScopedURLAccess(url: URL(fileURLWithPath: path), didStart: false)
            }
            return ScopedURLAccess(url: nil, didStart: false)
        }

        var stale = false
        let url = try URL(
            resolvingBookmarkData: bookmarkData,
            options: [.withSecurityScope],
            relativeTo: nil,
            bookmarkDataIsStale: &stale
        )
        if stale {
            throw FolderAccessError.staleBookmark
        }
        let didStart = url.startAccessingSecurityScopedResource()
        return ScopedURLAccess(url: url, didStart: didStart)
    }

    private func gitEnvironment(sshKeyURL: URL?) -> [String: String] {
        guard let sshKeyURL else { return [:] }
        return [
            "GIT_SSH_COMMAND": "ssh -i \(shellQuoted(sshKeyURL.path)) -o IdentitiesOnly=yes -o StrictHostKeyChecking=accept-new"
        ]
    }

    private func nonEmpty(_ value: String?) -> String? {
        guard let trimmed = value?.trimmingCharacters(in: .whitespacesAndNewlines), !trimmed.isEmpty else { return nil }
        return trimmed
    }

    private func shellQuoted(_ value: String) -> String {
        "'" + value.replacingOccurrences(of: "'", with: "'\\''") + "'"
    }

    private func requireSuccess(_ result: GitCommandResult, failure: GitSyncError) throws -> GitCommandResult {
        guard result.succeeded else {
            switch failure {
            case .gitConfigFailed:
                throw failure
            default:
                throw failure.withDetails(result.combinedOutput)
            }
        }
        return result
    }

    private func isMissingUpstreamOutput(_ output: String) -> Bool {
        output.localizedCaseInsensitiveContains("couldn't find remote ref")
            || output.localizedCaseInsensitiveContains("fatal: couldn't find remote ref")
            || output.localizedCaseInsensitiveContains("no such ref was fetched")
    }
}

enum GitSyncError: LocalizedError, Equatable, Sendable {
    case missingRepositoryURL
    case folderMissing(String)
    case gitInitFailed(String = "")
    case gitConfigFailed(String)
    case gitRemoteFailed(String = "")
    case gitCheckoutFailed(String = "")
    case gitStatusFailed(String = "")
    case gitAddFailed(String = "")
    case gitCommitFailed(String)
    case pullRebaseFailed(String)
    case gitPushFailed(String)

    var errorDescription: String? {
        switch self {
        case .missingRepositoryURL:
            return "Add a GitHub repository URL before syncing."
        case .folderMissing(let path):
            return "Folder not found: \(path)"
        case .gitInitFailed(let details):
            return "Could not initialize Git repository.\(suffix(details))"
        case .gitConfigFailed(let details):
            return details
        case .gitRemoteFailed(let details):
            return "Could not configure GitHub remote.\(suffix(details))"
        case .gitCheckoutFailed(let details):
            return "Could not switch to the configured branch.\(suffix(details))"
        case .gitStatusFailed(let details):
            return "Could not check folder changes.\(suffix(details))"
        case .gitAddFailed(let details):
            return "Could not stage folder changes.\(suffix(details))"
        case .gitCommitFailed(let details):
            return "Could not create snapshot commit.\(suffix(details))"
        case .pullRebaseFailed(let details):
            return "Could not safely pull remote changes before pushing.\(suffix(details))"
        case .gitPushFailed(let details):
            return "Could not push snapshot to GitHub.\(suffix(details))"
        }
    }

    var code: String {
        switch self {
        case .missingRepositoryURL: return "missing_repository_url"
        case .folderMissing: return "folder_missing"
        case .gitInitFailed: return "git_init_failed"
        case .gitConfigFailed: return "git_config_failed"
        case .gitRemoteFailed: return "git_remote_failed"
        case .gitCheckoutFailed: return "git_checkout_failed"
        case .gitStatusFailed: return "git_status_failed"
        case .gitAddFailed: return "git_add_failed"
        case .gitCommitFailed: return "git_commit_failed"
        case .pullRebaseFailed: return "pull_rebase_failed"
        case .gitPushFailed: return "git_push_failed"
        }
    }

    func userFacingError() -> UserFacingError {
        UserFacingError(
            code: code,
            title: "Sync failed",
            message: errorDescription ?? "GitFolder could not sync this folder.",
            recoverySuggestion: recoverySuggestion,
            technicalDetailsLogId: nil
        )
    }

    var recoverySuggestion: String? {
        switch self {
        case .missingRepositoryURL:
            return "Open Settings and add a GitHub SSH repository URL for this folder."
        case .gitConfigFailed:
            return "Run `git config --global user.name` and `git config --global user.email`, then try again."
        case .gitPushFailed, .pullRebaseFailed, .gitRemoteFailed:
            return "Check that the repository exists and your GitHub SSH key works in Terminal."
        case .folderMissing:
            return "Reconnect or remove this folder in Settings."
        default:
            return "Open the folder in Terminal, run Git manually once, then try Sync Now again."
        }
    }

    private func suffix(_ details: String) -> String {
        let trimmed = details.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? "" : " \(trimmed)"
    }

    func withDetails(_ details: String) -> GitSyncError {
        switch self {
        case .gitInitFailed: return .gitInitFailed(details)
        case .gitRemoteFailed: return .gitRemoteFailed(details)
        case .gitCheckoutFailed: return .gitCheckoutFailed(details)
        case .gitStatusFailed: return .gitStatusFailed(details)
        case .gitAddFailed: return .gitAddFailed(details)
        case .gitCommitFailed: return .gitCommitFailed(details)
        case .pullRebaseFailed: return .pullRebaseFailed(details)
        case .gitPushFailed: return .gitPushFailed(details)
        default: return self
        }
    }
}

struct SnapshotCommitMessage {
    static func make(date: Date) -> String {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]
        return "GitFolder snapshot \(formatter.string(from: date))"
    }
}

private struct ScopedURLAccess: Sendable {
    var url: URL?
    var didStart: Bool

    func stop() {
        if didStart {
            url?.stopAccessingSecurityScopedResource()
        }
    }
}

private extension GitCommandResult {
    var combinedOutput: String {
        [standardOutput, standardError]
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
            .joined(separator: "\n")
    }
}

private extension SyncedFolder {
    func marked(status: SyncStatus, message: String?, at date: Date) -> SyncedFolder {
        var copy = self
        copy.lastStatus = status
        copy.updatedAt = date
        copy.lastCheckedAt = date
        if let message {
            copy.lastError = UserFacingError(code: "status", title: message, message: message, recoverySuggestion: nil, technicalDetailsLogId: nil)
        }
        return copy
    }
}
