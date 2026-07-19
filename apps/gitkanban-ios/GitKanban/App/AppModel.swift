import Foundation
import GitKit
import GitPontCore
import GitPontGitHub
import GitPontGitLab
import Observation

/// Which hosted provider a connection targets. Self-hosted GitLab carries its own
/// server URL; the others are fixed instances.
enum ProviderChoice: String, CaseIterable, Identifiable, Codable {
    case github
    case gitlabCloud
    case gitlabSelfHosted
    var id: String { rawValue }

    var title: String {
        switch self {
        case .github: return "GitHub"
        case .gitlabCloud: return "GitLab.com"
        case .gitlabSelfHosted: return "GitLab (self-hosted)"
        }
    }

    var needsServerURL: Bool { self == .gitlabSelfHosted }
}

/// How the board is laid out: horizontal kanban lanes or a grouped vertical list.
enum BoardViewMode: String, CaseIterable, Identifiable {
    case lanes
    case list
    var id: String { rawValue }
}

/// An active provider connection: the git-pont provider + instance + token used for
/// every API call, plus the signed-in account login.
struct ProviderConnection {
    let choice: ProviderChoice
    let instance: GitProviderInstance
    let provider: any GitProvider
    let token: String
    let login: String

    var requestContext: GitProviderRequestContext {
        let now = Date()
        let connection = GitConnection(
            id: instance.id, instance: instance, accountID: login, accountLogin: login,
            authMethod: .personalAccessToken, createdAt: now, updatedAt: now
        )
        return GitProviderRequestContext(connection: connection, credential: GitCredential(accessToken: token))
    }
}

/// The top-level model for GitKanban iOS. Provider-agnostic: connects to GitHub,
/// GitLab.com, or a self-hosted GitLab with a personal access token (via git-pont),
/// then loads/edits the board over the provider API — no local clone.
@MainActor
@Observable
final class AppModel {
    // MARK: Connection
    var connection: ProviderConnection?
    var isConnecting = false
    var isRestoring = true

    // MARK: Repos
    var repos: [GitRepository] = []
    var isLoadingRepos = false

    // MARK: Active board
    /// Boards (repos) the user has added — shown on the home screen. Persisted.
    var addedRepos: [AddedRepo] = []
    var activeBoardFolder: String?
    /// The open board's repo (nil = home list). Persisted so it reopens on launch.
    var activeRepo: AddedRepo?
    var workspace: Workspace?
    var selectedProject: BoardProject?
    var board: LoadedBoard?
    var isLoadingBoard = false
    var isSaving = false

    // MARK: Presentation
    var selectedCard: Card?
    var newTaskLane: Lane?
    var boardViewMode: BoardViewMode = .lanes

    // MARK: Filters + search
    var filterAssignee: String?
    var filterPriority: String?
    var filterType: String?
    var isShowingSearch = false
    var searchText = ""

    var hasActiveFilters: Bool {
        filterAssignee != nil || filterPriority != nil || filterType != nil
    }

    func clearFilters() {
        filterAssignee = nil
        filterPriority = nil
        filterType = nil
    }

    func matchesFilters(_ card: Card) -> Bool {
        if let filterAssignee, card.fields.assignee != filterAssignee { return false }
        if let filterPriority, card.fields.priority != filterPriority { return false }
        if let filterType, card.fields.type != filterType { return false }
        return true
    }

    /// Every card on the current board (all lanes + uncategorised).
    var allCards: [Card] {
        (board?.columns.flatMap(\.cards) ?? []) + (board?.uncategorised ?? [])
    }

    // MARK: Status
    var errorMessage: String?

    var isConnected: Bool { connection != nil }

    // MARK: Persistence
    @ObservationIgnored private let keychain = KeychainService(
        service: Bundle.main.bundleIdentifier ?? "app.hakobs.gitkanban"
    )
    @ObservationIgnored private let defaults = UserDefaults.standard
    @ObservationIgnored private let connectionKey = "gitkanban.connection"
    @ObservationIgnored private let addedReposKey = "gitkanban.addedReposV2"
    @ObservationIgnored private let activeRepoKey = "gitkanban.activeRepo"
    @ObservationIgnored private let activeBoardKey = "gitkanban.activeBoard"

    @ObservationIgnored private var source: (any BoardWritable)?
    /// True when viewing the offline in-memory demo board (no provider connection).
    var isDemo = false

    // MARK: - Lifecycle

    func restore() async {
        defer { isRestoring = false }
        loadAddedRepos()
        guard let data = defaults.data(forKey: connectionKey),
              let stored = try? JSONDecoder().decode(StoredConnection.self, from: data),
              let token = ((try? keychain.load()) ?? nil)?.trimmingCharacters(in: .whitespacesAndNewlines),
              !token.isEmpty else { return }
        await connect(choice: stored.choice, serverURL: stored.serverURL, token: token, persist: false)
        // Reopen the last board so relaunching lands where you left off.
        if isConnected,
           let savedRepo = defaults.string(forKey: activeRepoKey),
           let repo = addedRepos.first(where: { $0.fullName == savedRepo }),
           let folder = defaults.string(forKey: activeBoardKey),
           repo.boards.contains(where: { $0.folder == folder }) {
            await openBoard(repo, folder: folder)
        }
    }

    // MARK: - Repos & boards

    private func persistAddedRepos() {
        if let data = try? JSONEncoder().encode(addedRepos) { defaults.set(data, forKey: addedReposKey) }
    }
    private func loadAddedRepos() {
        guard let data = defaults.data(forKey: addedReposKey),
              let saved = try? JSONDecoder().decode([AddedRepo].self, from: data) else { return }
        addedRepos = saved
    }

    /// Add a repository (no boards yet). The caller then browses it to pick boards.
    @discardableResult
    func addRepo(_ repo: GitRepository) -> AddedRepo {
        if let existing = addedRepos.first(where: { $0.fullName == "\(repo.reference.namespace)/\(repo.reference.name)" }) {
            return existing
        }
        let added = AddedRepo(
            namespace: repo.reference.namespace,
            name: repo.reference.name,
            branch: repo.reference.defaultBranch ?? "main",
            isPrivate: repo.isPrivate,
            boards: []
        )
        addedRepos.append(added)
        addedRepos.sort { $0.fullName.localizedCaseInsensitiveCompare($1.fullName) == .orderedAscending }
        persistAddedRepos()
        return added
    }

    func removeAddedRepo(_ repo: AddedRepo) {
        addedRepos.removeAll { $0.id == repo.id }
        persistAddedRepos()
        if activeRepo?.id == repo.id { closeRepo() }
    }

    /// Set which boards are selected for a repo (from the browse/multi-select step).
    func setBoards(_ boards: [SelectedBoard], for repoID: String) {
        guard let index = addedRepos.firstIndex(where: { $0.id == repoID }) else { return }
        addedRepos[index].boards = boards.sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
        persistAddedRepos()
    }

    /// Remove one board from a repo.
    func removeBoard(_ board: SelectedBoard, from repo: AddedRepo) {
        guard let index = addedRepos.firstIndex(where: { $0.id == repo.id }) else { return }
        addedRepos[index].boards.removeAll { $0.id == board.id }
        persistAddedRepos()
    }

    /// A file source rooted at a repo's root (no subpath — boards are addressed by folder).
    private func makeSource(for repo: AddedRepo) -> GitPontFileSource? {
        guard let connection else { return nil }
        return GitPontFileSource(
            provider: connection.provider, instance: connection.instance,
            owner: repo.namespace, repo: repo.name, branch: repo.branch, token: connection.token)
    }

    /// Cached total task counts per board (key = repoID|folder), for the boards list.
    var boardCounts: [String: Int] = [:]

    func boardCount(_ repo: AddedRepo, _ folder: String) -> Int? { boardCounts["\(repo.id)|\(folder)"] }

    /// Lazily count a board's tasks for the boards list (once, then cached).
    func loadBoardCount(_ repo: AddedRepo, _ folder: String) async {
        let key = "\(repo.id)|\(folder)"
        guard boardCounts[key] == nil, let source = makeSource(for: repo) else { return }
        let count = (try? await RemoteBoardStore.taskCount(source: source, folder: folder)) ?? 0
        boardCounts[key] = count
    }

    /// The subfolders under a repo-relative path (`""` = repo root) — for browsing to
    /// pick board folders yourself, no scanning/heuristics.
    func listFolders(in repo: AddedRepo, at path: String) async -> [BoardFileEntry] {
        guard let source = makeSource(for: repo) else { return [] }
        let entries = (try? await source.list(path)) ?? []
        return entries
            .filter { $0.kind == .directory && !$0.name.hasPrefix(".") && $0.name != "node_modules" }
            .sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
    }

    // MARK: - Connect

    /// Validate a token against the chosen provider, then load its repositories.
    func connect(choice: ProviderChoice, serverURL rawServerURL: String?, token rawToken: String, persist: Bool = true) async {
        let token = rawToken.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !token.isEmpty else { errorMessage = "Enter a personal access token."; return }

        isConnecting = true
        errorMessage = nil
        defer { isConnecting = false }

        let instance: GitProviderInstance
        let provider: any GitProvider
        switch choice {
        case .github:
            instance = .github
            provider = GitHubProvider(httpClient: URLSessionHTTPClient())
        case .gitlabCloud:
            instance = .gitLabCloud
            provider = GitLabProvider(httpClient: URLSessionHTTPClient(), instances: [.gitLabCloud])
        case .gitlabSelfHosted:
            guard let raw = rawServerURL?.trimmingCharacters(in: .whitespacesAndNewlines), !raw.isEmpty,
                  let url = URL(string: raw.hasPrefix("http") ? raw : "https://\(raw)") else {
                errorMessage = "Enter a valid GitLab server URL."
                return
            }
            instance = .gitLabSelfHosted(baseURL: url)
            provider = GitLabProvider(httpClient: URLSessionHTTPClient(), instances: [instance])
        }

        await establish(choice: choice, instance: instance, provider: provider, token: token, serverURL: rawServerURL, persist: persist)
    }

    /// Validate a token/credential against a provider, set the active connection,
    /// persist it, and load repositories. Shared by the token and OAuth connect paths.
    private func establish(
        choice: ProviderChoice, instance: GitProviderInstance, provider: any GitProvider,
        token: String, serverURL: String?, persist: Bool
    ) async {
        do {
            let account = try await provider.account(instance: instance, credential: GitCredential(accessToken: token))
            connection = ProviderConnection(
                choice: choice, instance: instance, provider: provider, token: token, login: account.login
            )
            if persist {
                try? keychain.save(token)
                let stored = StoredConnection(choice: choice, serverURL: serverURL)
                if let data = try? JSONEncoder().encode(stored) { defaults.set(data, forKey: connectionKey) }
            }
            await loadRepos()
        } catch {
            errorMessage = "Could not connect: \(error.localizedDescription)"
        }
    }

    // MARK: - GitHub OAuth (device flow)

    /// The active GitHub device-flow session (user code + verification URL) while the
    /// user authorises in a browser. Non-nil means the Connect screen shows the code.
    var deviceAuth: GitOAuthDeviceSession?

    @ObservationIgnored private let gitHubOAuthConfig = OAuthAppConfig(
        clientID: "Ov23li24tWFt7qLuLqCe", scopes: ["repo"]
    )

    /// Begin GitHub sign-in with the OAuth device flow: request a user code, surface it
    /// for the browser, then poll until the user authorises.
    func startGitHubOAuth() async {
        errorMessage = nil
        isConnecting = true
        let provider = GitHubProvider(httpClient: URLSessionHTTPClient(), oauth: gitHubOAuthConfig)
        do {
            let result = try await provider.startOAuth(GitOAuthStartRequest(
                instance: .github, method: .oauthDevice, appConfig: gitHubOAuthConfig))
            guard case let .device(session) = result else {
                errorMessage = "Unexpected OAuth response from GitHub."
                isConnecting = false
                return
            }
            deviceAuth = session
            await pollGitHubOAuth(provider: provider, session: session)
        } catch {
            errorMessage = "Could not start sign-in: \(error.localizedDescription)"
            isConnecting = false
        }
    }

    func cancelOAuth() {
        deviceAuth = nil
        isConnecting = false
    }

    private func pollGitHubOAuth(provider: GitHubProvider, session: GitOAuthDeviceSession) async {
        var interval = max(session.interval, 5)
        while Date() < session.expiresAt {
            try? await Task.sleep(nanoseconds: UInt64(interval * 1_000_000_000))
            if deviceAuth == nil { return } // cancelled by the user
            do {
                let credential = try await provider.completeOAuth(GitOAuthCompletionRequest(
                    instance: .github, method: .oauthDevice, appConfig: gitHubOAuthConfig,
                    deviceCode: session.deviceCode))
                deviceAuth = nil
                await establish(choice: .github, instance: .github, provider: provider,
                                token: credential.accessToken, serverURL: nil, persist: true)
                isConnecting = false
                return
            } catch GitPontError.authenticationFailed(let message) {
                let m = message.lowercased()
                if m.contains("slow") { interval += 5 }
                if m.contains("denied") || m.contains("declined") { finishOAuth(error: "Sign-in was declined on GitHub."); return }
                if m.contains("expired") { finishOAuth(error: "The code expired. Please try again."); return }
                continue  // authorization_pending / transient: keep waiting
            } catch {
                continue  // transient (e.g. network) — keep the screen and poll again
            }
        }
        finishOAuth(error: "Sign-in timed out. Please try again.")
    }

    private func finishOAuth(error: String) {
        guard deviceAuth != nil else { return }
        deviceAuth = nil
        isConnecting = false
        errorMessage = error
    }

    func signOut() {
        try? keychain.delete()
        defaults.removeObject(forKey: connectionKey)
        defaults.removeObject(forKey: addedReposKey)
        defaults.removeObject(forKey: activeRepoKey)
        defaults.removeObject(forKey: activeBoardKey)
        connection = nil
        repos = []
        addedRepos = []
        activeRepo = nil
        activeBoardFolder = nil
        workspace = nil
        selectedProject = nil
        board = nil
        source = nil
    }

    // MARK: - Repos

    func loadRepos() async {
        guard let connection else { return }
        isLoadingRepos = true
        errorMessage = nil
        defer { isLoadingRepos = false }
        do {
            let list = try await connection.provider.repositories(context: connection.requestContext)
            // Most-recently-updated first, so active repos stay on top.
            repos = list.items.sorted { ($0.updatedAt ?? .distantPast) > ($1.updatedAt ?? .distantPast) }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func fullName(_ repo: GitRepository) -> String {
        "\(repo.reference.namespace)/\(repo.reference.name)"
    }

    // MARK: - Open a board

    /// Open a specific board (project folder) within a repo.
    func openBoard(_ repo: AddedRepo, folder: String) async {
        guard let source = makeSource(for: repo) else { return }
        activeRepo = repo
        activeBoardFolder = folder
        self.source = source
        errorMessage = nil
        loadedBacklogLanes = []
        isLoadingBoard = true
        defer { isLoadingBoard = false }
        defaults.set(repo.fullName, forKey: activeRepoKey)
        defaults.set(folder, forKey: activeBoardKey)
        do {
            let loaded = try await RemoteBoardStore.loadBoard(source: source, folder: folder, loadBacklog: false)
            // A single-project workspace, so edit/reload paths keep working.
            workspace = Workspace(rootConfig: loaded.rootConfig, projects: [loaded.project])
            selectedProject = loaded.project
            board = loaded.board
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    /// Load the offline in-memory demo board — explore the app without connecting.
    func loadDemo() async {
        isDemo = true
        isRestoring = false
        errorMessage = nil
        isLoadingBoard = true
        defer { isLoadingBoard = false }
        source = InMemoryBoardSource.demo()
        await loadWorkspaceAndFirstProject()
    }

    private func loadWorkspaceAndFirstProject() async {
        guard let source else { return }
        do {
            let workspace = try await RemoteBoardStore.loadWorkspace(source: source)
            self.workspace = workspace
            if let first = workspace.projects.first {
                await selectProject(first)
            } else {
                selectedProject = nil
                board = nil
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    /// Backlog lanes whose cards have been lazily loaded (they're skipped on first load).
    var loadedBacklogLanes: Set<String> = []
    var loadingBacklogLane: String?

    func selectProject(_ project: BoardProject) async {
        guard let source, let workspace else { return }
        isLoadingBoard = true
        defer { isLoadingBoard = false }
        loadedBacklogLanes = []
        do {
            board = try await RemoteBoardStore.loadProjectBoard(
                source: source, project: project, rootConfig: workspace.rootConfig, loadBacklog: false
            )
            selectedProject = project
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    /// Lazily load a backlog lane's cards on demand.
    func loadBacklogLane(_ lane: Lane) async {
        guard let source, let project = selectedProject, let rootConfig = workspace?.rootConfig, var board else { return }
        loadingBacklogLane = lane.id
        defer { loadingBacklogLane = nil }
        let cards = (try? await RemoteBoardStore.loadLaneCards(
            source: source, project: project, lane: lane, rootConfig: rootConfig)) ?? []
        if let index = board.columns.firstIndex(where: { $0.lane.id == lane.id }) {
            board.columns[index].cards = cards
            self.board = board
        }
        loadedBacklogLanes.insert(lane.id)
    }

    func closeRepo() {
        activeRepo = nil
        activeBoardFolder = nil
        workspace = nil
        selectedProject = nil
        board = nil
        source = nil
        isDemo = false
        clearFilters()
        defaults.removeObject(forKey: activeRepoKey)
        defaults.removeObject(forKey: activeBoardKey)
    }

    // MARK: - Projects (board settings)

    /// Default 5 lanes for a new project.
    static func defaultProjectLanes() -> [Lane] {
        lanes(fromNames: ["To do", "In Progress", "In Review", "Testing", "Done"], terminalLast: true)
    }
    static func defaultPriorities() -> [Priority] { (0...3).map { Priority(id: "P\($0)") } }

    /// Build lanes from display names: folder = "<n>. <name>", id/status = slug.
    static func lanes(fromNames names: [String], terminalLast: Bool = false) -> [Lane] {
        let cleaned = names.map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }.filter { !$0.isEmpty }
        return cleaned.enumerated().map { index, name in
            let slug = name.lowercased().replacingOccurrences(of: " ", with: "-")
            return Lane(id: slug, name: name, folder: "\(index + 1). \(name)", status: slug,
                        terminal: (terminalLast && index == cleaned.count - 1) ? true : nil)
        }
    }

    /// Create a project: write its README config (one commit). Lanes render from config,
    /// so empty lane folders aren't needed — they're created on the first task add.
    func createProject(name rawName: String, description: String, lanes: [Lane],
                       priorities: [Priority], users: [User], epics: [Epic]) async {
        let name = rawName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let source else { return }
        guard !name.isEmpty, !name.contains("/"), !name.contains("\\") else {
            errorMessage = "A project needs a name without slashes."; return
        }
        let readme = BoardStore.renderProjectReadme(
            name: name, description: description, lanes: lanes,
            priorities: priorities, users: users, types: [], epics: epics)
        isSaving = true; errorMessage = nil
        do { try await source.write(path: "\(name)/README.md", text: readme, message: "Create project \(name)") }
        catch { errorMessage = error.localizedDescription }
        isSaving = false
        await reloadWorkspace(selecting: name)
    }

    /// Save a project's settings by rewriting its README config (one commit).
    func saveProjectSettings(project: BoardProject, name: String, description: String, lanes: [Lane],
                            priorities: [Priority], users: [User], types: [String], epics: [Epic]) async {
        guard let source else { return }
        let readme = BoardStore.renderProjectReadme(
            name: name, description: description, lanes: lanes,
            priorities: priorities, users: users, types: types, epics: epics)
        isSaving = true; errorMessage = nil
        do { try await source.write(path: "\(project.folder)/README.md", text: readme, message: "Update \(name) settings") }
        catch { errorMessage = error.localizedDescription }
        isSaving = false
        await reloadWorkspace(selecting: project.folder)
    }

    /// Reload the workspace and select the project with the given folder (or the first).
    private func reloadWorkspace(selecting folder: String) async {
        guard let source else { return }
        do {
            let workspace = try await RemoteBoardStore.loadWorkspace(source: source)
            self.workspace = workspace
            let project = workspace.projects.first { $0.folder == folder } ?? workspace.projects.first
            if let project { await selectProject(project) }
        } catch { errorMessage = error.localizedDescription }
    }

    // MARK: - Writes (over the provider API via git-pont)

    func createTask(
        title rawTitle: String, lane: Lane,
        priority: String?, type: String?, assignee: String?, epic: String? = nil, body: String
    ) async {
        let title = rawTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let source, let project = selectedProject, !title.isEmpty, !lane.folder.isEmpty else { return }
        let id = uniqueID(for: title, lane: lane)
        let path = "\(project.folder)/\(lane.folder)/\(id).md"
        var content = CardText.make(
            id: id, title: title, project: project.name, status: lane.status,
            priority: priority, type: type, assignee: assignee, body: body
        )
        if let epic, !epic.isEmpty { content = CardText.update(content, set: ["epic": epic]) }
        await performWrite { try await source.write(path: path, text: content, message: "Add task \(id)") }
    }

    func moveCard(_ card: Card, to lane: Lane) async {
        guard let source, let project = selectedProject,
              let location = location(of: card), let fileName = card.fileName,
              location.lane.id != lane.id, !lane.folder.isEmpty else { return }

        // Optimistic: move the card between columns in memory right away so a drag lands
        // instantly; the git commit runs in the background and reverts on failure.
        if var board, let srcIdx = board.columns.firstIndex(where: { $0.lane.id == location.lane.id }),
           let dstIdx = board.columns.firstIndex(where: { $0.lane.id == lane.id }),
           let cardIdx = board.columns[srcIdx].cards.firstIndex(where: { $0.fields.id == card.fields.id }) {
            var moved = board.columns[srcIdx].cards.remove(at: cardIdx)
            moved.fields.status = lane.status
            board.columns[dstIdx].cards.append(moved)
            self.board = board
        }

        let original = (try? await source.readText(location.path)) ?? card.body
        let updated = CardText.update(original, set: ["status": lane.status])
        let newPath = "\(project.folder)/\(lane.folder)/\(fileName)"
        let message = "Move \(card.fields.id) to \(lane.name)"
        isSaving = true
        errorMessage = nil
        do {
            try await source.write(path: newPath, text: updated, message: message)
            try await source.delete(path: location.path, message: message)
        } catch {
            errorMessage = error.localizedDescription
            if let project = selectedProject { await selectProject(project) } // revert
        }
        isSaving = false
    }

    func updateCard(
        _ card: Card, title: String, laneID: String,
        priority: String, type: String, assignee: String, epic: String = "", body: String
    ) async {
        guard let source, let project = selectedProject,
              let location = location(of: card), let fileName = card.fileName else { return }
        let lane = board?.config.lanes.first { $0.id == laneID } ?? location.lane
        let original = (try? await source.readText(location.path)) ?? card.body
        let updated = CardText.update(original, set: [
            "title": title,
            "status": lane.status,
            "priority": priority.isEmpty ? nil : priority,
            "type": type.isEmpty ? nil : type,
            "assignee": assignee.isEmpty ? nil : assignee,
            "epic": epic.isEmpty ? nil : epic,
        ], body: body)
        let moved = lane.id != location.lane.id
        let newPath = moved ? "\(project.folder)/\(lane.folder)/\(fileName)" : location.path
        await performWrite {
            try await source.write(path: newPath, text: updated, message: "Update \(card.fields.id)")
            if moved { try await source.delete(path: location.path, message: "Update \(card.fields.id)") }
        }
    }

    func deleteCard(_ card: Card) async {
        guard let source, let location = location(of: card) else { return }
        await performWrite { try await source.delete(path: location.path, message: "Delete \(card.fields.id)") }
    }

    /// Update one or more frontmatter fields on a card in place (no lane move).
    func setCardField(_ card: Card, _ updates: [String: String?]) async {
        guard let source, let location = location(of: card) else { return }
        let original = (try? await source.readText(location.path)) ?? card.body
        let updated = CardText.update(original, set: updates)
        await performWrite { try await source.write(path: location.path, text: updated, message: "Update \(card.fields.id)") }
    }

    /// Duplicate a card into the same lane with a fresh id.
    func duplicateCard(_ card: Card) async {
        guard let source, let project = selectedProject, let location = location(of: card) else { return }
        let original = (try? await source.readText(location.path)) ?? card.body
        let base = card.fields.title.isEmpty ? "task" : card.fields.title
        let newID = uniqueID(for: base, lane: location.lane)
        let newPath = "\(project.folder)/\(location.lane.folder)/\(newID).md"
        let content = CardText.update(original, set: ["id": newID])
        await performWrite { try await source.write(path: newPath, text: content, message: "Duplicate \(card.fields.id)") }
    }

    // MARK: - Attachments
    //
    // Files attached to a card live in a per-project folder namespaced by card id:
    // <project>/attachments/<cardId>/<filename>. They're committed to the repo (so they
    // show on GitHub by browsing that folder) and listed in the card detail.

    private func attachmentsDir(for card: Card) -> String? {
        guard let project = selectedProject else { return nil }
        return "\(project.folder)/attachments/\(card.fields.id)"
    }

    /// The files attached to a card.
    func attachments(for card: Card) async -> [BoardFileEntry] {
        guard let source, let dir = attachmentsDir(for: card) else { return [] }
        let entries = (try? await source.list(dir)) ?? []
        return entries.filter { $0.kind == .file }.sorted { $0.name < $1.name }
    }

    /// Attach a file to a card (committed to its attachments folder).
    @discardableResult
    func attachFile(to card: Card, data: Data, filename: String) async -> Bool {
        guard let source, let dir = attachmentsDir(for: card) else { return false }
        let safe = filename.map { $0.isLetter || $0.isNumber || "._- ".contains($0) ? $0 : "-" }
        let name = String(safe).trimmingCharacters(in: .whitespaces)
        isSaving = true; errorMessage = nil; defer { isSaving = false }
        do {
            try await source.writeData(path: "\(dir)/\(name)", data: data, message: "Attach \(name) to \(card.fields.id)")
            return true
        } catch { errorMessage = error.localizedDescription; return false }
    }

    func deleteAttachment(path: String) async {
        guard let source else { return }
        isSaving = true; errorMessage = nil; defer { isSaving = false }
        try? await source.delete(path: path, message: "Remove attachment \(path)")
    }

    func readAttachment(path: String) async -> Data? {
        guard let source else { return nil }
        return try? await source.readData(path)
    }

    /// The github.com blob URL for a card's file (Copy Link / Open on GitHub).
    func githubURL(for card: Card) -> URL? {
        guard connection?.choice == .github, let repo = activeRepo, let location = location(of: card) else { return nil }
        let encoded = location.path.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? location.path
        return URL(string: "https://github.com/\(repo.namespace)/\(repo.name)/blob/\(repo.branch)/\(encoded)")
    }

    /// Persist a new within-lane order by rewriting each card's `order` frontmatter.
    /// Only cards whose order actually changed are committed.
    func reorderCards(in lane: Lane, orderedIDs: [String]) async {
        guard let source, let project = selectedProject, let board,
              let column = board.columns.first(where: { $0.lane.id == lane.id }) else { return }
        let byID = Dictionary(uniqueKeysWithValues: column.cards.map { ($0.fields.id, $0) })
        isSaving = true
        errorMessage = nil
        do {
            for (index, id) in orderedIDs.enumerated() {
                guard let card = byID[id], let fileName = card.fileName else { continue }
                let newOrder = String(index + 1)
                if card.fields.order == newOrder { continue }
                let path = "\(project.folder)/\(lane.folder)/\(fileName)"
                let original = (try? await source.readText(path)) ?? card.body
                let updated = CardText.update(original, set: ["order": newOrder])
                try await source.write(path: path, text: updated, message: "Reorder \(id)")
            }
        } catch {
            errorMessage = error.localizedDescription
        }
        isSaving = false
        await selectProject(project)
    }

    // MARK: Write helpers

    private func performWrite(_ operation: @escaping () async throws -> Void) async {
        guard let project = selectedProject else { return }
        isSaving = true
        errorMessage = nil
        do { try await operation() } catch { errorMessage = error.localizedDescription }
        isSaving = false
        await selectProject(project)
    }

    private func location(of card: Card) -> (lane: Lane, path: String)? {
        guard let project = selectedProject, let board, let fileName = card.fileName else { return nil }
        guard let column = board.columns.first(where: { column in
            column.cards.contains { $0.fields.id == card.fields.id }
        }) else { return nil }
        return (column.lane, "\(project.folder)/\(column.lane.folder)/\(fileName)")
    }

    private func uniqueID(for title: String, lane: Lane) -> String {
        let base = slug(title).isEmpty ? "task" : slug(title)
        let existing = Set((board?.columns.first { $0.lane.id == lane.id }?.cards ?? [])
            .compactMap { $0.fileName })
        var name = "\(base).md"
        var n = 2
        while existing.contains(name) { name = "\(base)-\(n).md"; n += 1 }
        return String(name.dropLast(3))
    }

    private func slug(_ s: String) -> String {
        let mapped = s.lowercased().map { ($0.isLetter || $0.isNumber) ? $0 : "-" }
        var result = String(mapped)
        while result.contains("--") { result = result.replacingOccurrences(of: "--", with: "-") }
        return result.trimmingCharacters(in: CharacterSet(charactersIn: "-"))
    }

    private struct StoredConnection: Codable {
        let choice: ProviderChoice
        let serverURL: String?
    }
}
