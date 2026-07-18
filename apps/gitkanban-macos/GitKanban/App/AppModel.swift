import AppKit
import Foundation
import GitKit
import Observation

/// The single top-level model for GitKanban. Owns the GitHub connection, the
/// app-managed repo checkout, and the loaded board. The app OWNS the checkout
/// (it clones into its own Application Support container); it is not a folder viewer.
@MainActor
@Observable
final class AppModel {
    // MARK: State — auth
    var token: String?
    var login: String?
    var deviceAuth: GitHubDeviceAuthorization?
    var isAuthorizing = false

    // MARK: State — repos
    var repos: [GitHubRepo] = []
    var isLoadingRepos = false

    // MARK: State — active checkout / board
    var activeRepo: GitHubRepo?
    var checkoutURL: URL?
    var workspace: Workspace?
    var selectedProject: BoardProject?
    var board: LoadedBoard?
    var selectedCard: Card?

    // MARK: State — status
    var syncStatus = "Idle"
    var errorMessage: String?

    // MARK: Services
    @ObservationIgnored private let keychain = KeychainService(
        service: Bundle.main.bundleIdentifier ?? "app.hakobs.gitkanban"
    )
    @ObservationIgnored private let oauth = GitHubOAuthService(
        clientID: "Ov23li24tWFt7qLuLqCe",
        userAgent: "GitKanban"
    )
    @ObservationIgnored private let reposService = GitHubReposService()
    @ObservationIgnored private let git = ShellGitEngine()
    @ObservationIgnored private let runner = GitProcessRunner()

    // MARK: Computed
    var isConnected: Bool { token != nil }
    var auth: GitAuth { .httpsToken(username: login ?? "x-access-token", token: token ?? "") }

    // MARK: - Lifecycle

    /// Load a stored token from the keychain and, if present, restore the session.
    func restore() async {
        do {
            guard let stored = try keychain.load()?.trimmingCharacters(in: .whitespacesAndNewlines),
                  !stored.isEmpty else { return }
            token = stored
            login = try? await oauth.loadViewerLogin(token: stored)
            await loadRepos()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    // MARK: - Connect

    /// Run the GitHub device flow: request a code, open the verification URL, then
    /// wait for the user to authorise. Persists the token on success.
    func connect() async {
        isAuthorizing = true
        errorMessage = nil
        defer { isAuthorizing = false }
        do {
            let authorization = try await oauth.requestDeviceAuthorization()
            deviceAuth = authorization
            NSWorkspace.shared.open(authorization.verificationURI)

            let accessToken = try await oauth.waitForAccessToken(authorization: authorization)
            try keychain.save(accessToken)
            token = accessToken
            deviceAuth = nil
            login = try? await oauth.loadViewerLogin(token: accessToken)
            await loadRepos()
        } catch {
            deviceAuth = nil
            errorMessage = error.localizedDescription
        }
    }

    /// Clear the token and all session state.
    func signOut() {
        try? keychain.delete()
        token = nil
        login = nil
        deviceAuth = nil
        repos = []
        activeRepo = nil
        checkoutURL = nil
        workspace = nil
        selectedProject = nil
        board = nil
        selectedCard = nil
        syncStatus = "Idle"
        errorMessage = nil
    }

    // MARK: - Repos

    func loadRepos() async {
        guard let token else { return }
        isLoadingRepos = true
        errorMessage = nil
        defer { isLoadingRepos = false }
        do {
            let fetched = try await reposService.listRepositories(token: token)
            repos = fetched.sorted { $0.fullName.localizedCaseInsensitiveCompare($1.fullName) == .orderedAscending }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    // MARK: - Open a repo (own-the-checkout)

    /// Make `repo` the active board. Clones it into the app's own checkout dir the
    /// first time; pulls afterwards. Then loads the workspace and selects the first
    /// project.
    func openRepo(_ repo: GitHubRepo) async {
        activeRepo = repo
        errorMessage = nil
        selectedCard = nil
        do {
            let dir = try checkoutDirectory(for: repo)
            let gitDir = dir.appendingPathComponent(".git")
            if FileManager.default.fileExists(atPath: gitDir.path) {
                syncStatus = "Pulling…"
                _ = try await git.pullRebase(at: dir, auth: auth)
            } else {
                syncStatus = "Cloning…"
                try await git.clone(repo.cloneURL, to: dir, auth: auth)
                try configureIdentity(at: dir)
            }
            checkoutURL = dir
            workspace = try BoardStore.loadWorkspace(at: dir)
            if let first = workspace?.projects.first {
                selectProject(first)
            } else {
                selectedProject = nil
                board = nil
            }
            syncStatus = "Ready"
        } catch {
            syncStatus = "Error"
            errorMessage = error.localizedDescription
        }
    }

    /// Re-pull the active repo and reload the board (Refresh action).
    func refresh() async {
        guard let repo = activeRepo else { return }
        await openRepo(repo)
    }

    /// Leave the active board and return to the repo picker.
    func closeRepo() {
        activeRepo = nil
        checkoutURL = nil
        workspace = nil
        selectedProject = nil
        board = nil
        selectedCard = nil
        syncStatus = "Idle"
    }

    // MARK: - Projects

    func selectProject(_ project: BoardProject) {
        guard let checkoutURL, let workspace else { return }
        selectedCard = nil
        do {
            board = try BoardStore.loadProjectBoard(
                root: checkoutURL,
                project: project,
                rootConfig: workspace.rootConfig
            )
            selectedProject = project
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    // MARK: - Card files

    /// The on-disk file backing a card: checkout / project.folder / lane.folder / fileName.
    func fileURL(for card: Card) -> URL? {
        guard let relative = relativePath(for: card), let checkoutURL else { return nil }
        return checkoutURL.appendingPathComponent(relative)
    }

    /// The card's path relative to the checkout root (for staging/committing).
    private func relativePath(for card: Card) -> String? {
        guard let project = selectedProject, let fileName = card.fileName, let board else { return nil }
        guard let column = board.columns.first(where: { col in
            col.cards.contains { $0.fields.id == card.fields.id }
        }) else { return nil }
        return "\(project.folder)/\(column.lane.folder)/\(fileName)"
    }

    func canEdit(_ card: Card) -> Bool { fileURL(for: card) != nil }

    /// The raw markdown file (frontmatter + body) as plain text, for the editor.
    func rawText(for card: Card) -> String? {
        guard let url = fileURL(for: card) else { return nil }
        return try? String(contentsOf: url, encoding: .utf8)
    }

    /// Write the edited text to the card's file, then sync in the background:
    /// pull (best-effort), commit, push. Reloads the board afterward.
    func saveCard(_ card: Card, text: String) async {
        guard let checkoutURL, let relative = relativePath(for: card) else {
            errorMessage = "This card has no file on disk to save to."
            return
        }
        let fileURL = checkoutURL.appendingPathComponent(relative)
        errorMessage = nil
        do {
            try text.write(to: fileURL, atomically: true, encoding: .utf8)

            syncStatus = "Committing…"
            _ = try? await git.pullRebase(at: checkoutURL, auth: auth)
            try await git.commit(at: checkoutURL, message: "Update \(card.fields.id)", paths: [relative])
            syncStatus = "Pushing…"
            try await git.push(at: checkoutURL, auth: auth)
            syncStatus = "Pushed"
        } catch {
            syncStatus = "Error"
            errorMessage = error.localizedDescription
        }

        // Reload the current project board so the UI reflects any status changes.
        if let project = selectedProject {
            selectProject(project)
        }
    }

    // MARK: - Helpers

    /// The app-managed checkout directory for a repo:
    /// Application Support/GitKanban/checkouts/<owner>-<name>. Parents are created.
    private func checkoutDirectory(for repo: GitHubRepo) throws -> URL {
        let support = try FileManager.default.url(
            for: .applicationSupportDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: true
        )
        let dir = support
            .appendingPathComponent("GitKanban", isDirectory: true)
            .appendingPathComponent("checkouts", isDirectory: true)
            .appendingPathComponent("\(repo.ownerLogin)-\(repo.name)", isDirectory: true)
        try FileManager.default.createDirectory(
            at: dir.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        return dir
    }

    /// Set the local commit identity in the checkout so commits are attributed.
    private func configureIdentity(at dir: URL) throws {
        let name = login ?? "GitKanban"
        let email = "\(login ?? "gitkanban")@users.noreply.github.com"
        try runner.run(["config", "user.name", name], in: dir)
        try runner.run(["config", "user.email", email], in: dir)
    }
}
