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
    var isCreatingProject = false
    var isShowingNewProjectSheet = false

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
    @ObservationIgnored private let defaults = UserDefaults.standard
    @ObservationIgnored private let lastRepoKey = "lastOpenedRepoFullName"

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
            // Re-open last session's repository (persisted in full, so it works
            // even for repos beyond the first page of the list).
            if let repo = loadLastRepo() ?? lastCheckoutRepo() {
                await openRepo(repo)
            }
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
        defaults.removeObject(forKey: lastRepoKey)
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
        persistLastRepo(repo)
        errorMessage = nil
        selectedCard = nil
        do {
            let dir = try checkoutDirectory(for: repo)
            let gitDir = dir.appendingPathComponent(".git")
            if FileManager.default.fileExists(atPath: gitDir.path) {
                // Only pull when the repo actually has commits — pulling an
                // unborn branch fails.
                if hasCommits(at: dir) {
                    syncStatus = "Pulling…"
                    _ = try await git.pullRebase(at: dir, auth: auth)
                }
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
        defaults.removeObject(forKey: lastRepoKey)
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

    /// Create a new project folder in the checkout: writes its `README.md`
    /// (frontmatter config + body), seeds each lane folder with a `.gitkeep`, then
    /// commits and pushes exactly like `saveCard`. Reloads the workspace and selects
    /// the new project on success.
    func createProject(
        name rawName: String,
        description: String,
        lanes: [Lane],
        priorities: [Priority],
        users: [User]
    ) async {
        let name = rawName.trimmingCharacters(in: .whitespacesAndNewlines)

        guard let checkoutURL else {
            errorMessage = "Open a repository before creating a project."
            return
        }
        guard !name.isEmpty else {
            errorMessage = "A project needs a name."
            return
        }
        guard !name.contains("/"), !name.contains("\\") else {
            errorMessage = "A project name can't contain slashes."
            return
        }
        let projectURL = checkoutURL.appendingPathComponent(name, isDirectory: true)
        guard !FileManager.default.fileExists(atPath: projectURL.path) else {
            errorMessage = "A folder named “\(name)” already exists."
            return
        }

        isCreatingProject = true
        errorMessage = nil
        defer { isCreatingProject = false }

        do {
            try FileManager.default.createDirectory(at: projectURL, withIntermediateDirectories: true)

            let readmeText = BoardStore.renderProjectReadme(
                name: name,
                description: description,
                lanes: lanes,
                priorities: priorities,
                users: users
            )
            try readmeText.write(
                to: projectURL.appendingPathComponent("README.md"),
                atomically: true,
                encoding: .utf8
            )

            for lane in lanes where !lane.folder.isEmpty {
                let laneURL = projectURL.appendingPathComponent(lane.folder, isDirectory: true)
                try FileManager.default.createDirectory(at: laneURL, withIntermediateDirectories: true)
                try "".write(to: laneURL.appendingPathComponent(".gitkeep"), atomically: true, encoding: .utf8)
            }

            syncStatus = "Creating project…"
            if hasCommits(at: checkoutURL) {
                _ = try? await git.pullRebase(at: checkoutURL, auth: auth)
            }
            try await git.commit(at: checkoutURL, message: "Create project \(name)", paths: [name])
            syncStatus = "Pushing…"
            try await git.push(at: checkoutURL, auth: auth)
            syncStatus = "Pushed"
        } catch {
            syncStatus = "Error"
            errorMessage = error.localizedDescription
        }

        do {
            workspace = try BoardStore.loadWorkspace(at: checkoutURL)
            if let project = workspace?.projects.first(where: { $0.folder == name }) {
                selectProject(project)
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    /// The default 5 lanes for a fresh project (To do → Done, with Done terminal).
    static func defaultProjectLanes() -> [Lane] {
        lanes(fromNames: ["To do", "In Progress", "In Review", "Testing", "Done"], terminalLast: true)
    }

    /// The default P0–P3 priorities for a fresh project.
    static func defaultPriorities() -> [Priority] {
        (0...3).map { Priority(id: "P\($0)") }
    }

    /// Build lanes from an ordered list of display names: `folder = "<n>. <name>"`
    /// and `id`/`status = name.lowercased()` with spaces replaced by dashes. When
    /// `terminalLast` is set, the final lane is marked terminal.
    static func lanes(fromNames names: [String], terminalLast: Bool = false) -> [Lane] {
        let cleaned = names
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
        return cleaned.enumerated().map { index, name in
            let slug = name.lowercased().replacingOccurrences(of: " ", with: "-")
            return Lane(
                id: slug,
                name: name,
                folder: "\(index + 1). \(name)",
                status: slug,
                terminal: (terminalLast && index == cleaned.count - 1) ? true : nil
            )
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
    // MARK: - Last-repo persistence

    private struct StoredRepo: Codable {
        var name: String
        var fullName: String
        var ownerLogin: String
        var cloneURL: String
        var defaultBranch: String
        var isPrivate: Bool
    }

    private func persistLastRepo(_ repo: GitHubRepo) {
        let stored = StoredRepo(
            name: repo.name, fullName: repo.fullName, ownerLogin: repo.ownerLogin,
            cloneURL: repo.cloneURL.absoluteString, defaultBranch: repo.defaultBranch,
            isPrivate: repo.isPrivate
        )
        if let data = try? JSONEncoder().encode(stored) {
            defaults.set(data, forKey: lastRepoKey)
        }
    }

    private func loadLastRepo() -> GitHubRepo? {
        guard let data = defaults.data(forKey: lastRepoKey),
              let stored = try? JSONDecoder().decode(StoredRepo.self, from: data),
              let url = URL(string: stored.cloneURL) else { return nil }
        return GitHubRepo(
            name: stored.name, fullName: stored.fullName, ownerLogin: stored.ownerLogin,
            cloneURL: url, defaultBranch: stored.defaultBranch, isPrivate: stored.isPrivate
        )
    }

    /// Fallback: reconstruct a repo from the most-recently-used checkout already on
    /// disk, by reading its `origin` remote. Works even if prefs didn't persist.
    private func lastCheckoutRepo() -> GitHubRepo? {
        guard let support = try? FileManager.default.url(
            for: .applicationSupportDirectory, in: .userDomainMask, appropriateFor: nil, create: false
        ) else { return nil }
        let root = support.appendingPathComponent("GitKanban/checkouts", isDirectory: true)
        let dirs = (try? FileManager.default.contentsOfDirectory(
            at: root, includingPropertiesForKeys: [.contentModificationDateKey], options: [.skipsHiddenFiles]
        )) ?? []
        let clones = dirs.filter { FileManager.default.fileExists(atPath: $0.appendingPathComponent(".git").path) }
        func modDate(_ url: URL) -> Date {
            (try? url.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate) ?? .distantPast
        }
        guard let dir = clones.max(by: { modDate($0) < modDate($1) }),
              let result = try? runner.run(["remote", "get-url", "origin"], in: dir),
              result.exitCode == 0,
              let url = URL(string: result.standardOutput.trimmingCharacters(in: .whitespacesAndNewlines))
        else { return nil }
        let comps = url.pathComponents.filter { $0 != "/" }
        guard comps.count >= 2 else { return nil }
        let owner = comps[comps.count - 2]
        var name = comps[comps.count - 1]
        if name.hasSuffix(".git") { name = String(name.dropLast(4)) }
        return GitHubRepo(
            name: name, fullName: "\(owner)/\(name)", ownerLogin: owner,
            cloneURL: url, defaultBranch: "main", isPrivate: false
        )
    }

    /// Whether the checkout has at least one commit (an unborn branch can't be pulled).
    private func hasCommits(at dir: URL) -> Bool {
        guard let result = try? runner.run(["rev-parse", "--verify", "--quiet", "HEAD"], in: dir) else {
            return false
        }
        return result.exitCode == 0
    }

    private func configureIdentity(at dir: URL) throws {
        let name = login ?? "GitKanban"
        let email = "\(login ?? "gitkanban")@users.noreply.github.com"
        try runner.run(["config", "user.name", name], in: dir)
        try runner.run(["config", "user.email", email], in: dir)
    }

}
