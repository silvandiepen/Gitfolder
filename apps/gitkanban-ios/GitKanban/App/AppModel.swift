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
    var activeRepo: GitRepository?
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

    @ObservationIgnored private var source: (any BoardWritable)?
    /// True when viewing the offline in-memory demo board (no provider connection).
    var isDemo = false

    // MARK: - Lifecycle

    func restore() async {
        defer { isRestoring = false }
        guard let data = defaults.data(forKey: connectionKey),
              let stored = try? JSONDecoder().decode(StoredConnection.self, from: data),
              let token = ((try? keychain.load()) ?? nil)?.trimmingCharacters(in: .whitespacesAndNewlines),
              !token.isEmpty else { return }
        await connect(choice: stored.choice, serverURL: stored.serverURL, token: token, persist: false)
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

        do {
            let account = try await provider.account(instance: instance, credential: GitCredential(accessToken: token))
            let connection = ProviderConnection(
                choice: choice, instance: instance, provider: provider, token: token, login: account.login
            )
            self.connection = connection
            if persist {
                try? keychain.save(token)
                let stored = StoredConnection(choice: choice, serverURL: rawServerURL)
                if let data = try? JSONEncoder().encode(stored) { defaults.set(data, forKey: connectionKey) }
            }
            await loadRepos()
        } catch {
            errorMessage = "Could not connect: \(error.localizedDescription)"
        }
    }

    func signOut() {
        try? keychain.delete()
        defaults.removeObject(forKey: connectionKey)
        connection = nil
        repos = []
        activeRepo = nil
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
            repos = list.items.sorted { fullName($0).localizedCaseInsensitiveCompare(fullName($1)) == .orderedAscending }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func fullName(_ repo: GitRepository) -> String {
        "\(repo.reference.namespace)/\(repo.reference.name)"
    }

    // MARK: - Open a board

    func openRepo(_ repo: GitRepository) async {
        guard let connection else { return }
        activeRepo = repo
        errorMessage = nil
        isLoadingBoard = true
        defer { isLoadingBoard = false }

        source = GitPontFileSource(
            provider: connection.provider,
            instance: connection.instance,
            owner: repo.reference.namespace,
            repo: repo.reference.name,
            branch: repo.reference.defaultBranch ?? "main",
            token: connection.token
        )
        await loadWorkspaceAndFirstProject()
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

    func selectProject(_ project: BoardProject) async {
        guard let source, let workspace else { return }
        isLoadingBoard = true
        defer { isLoadingBoard = false }
        do {
            board = try await RemoteBoardStore.loadProjectBoard(
                source: source, project: project, rootConfig: workspace.rootConfig
            )
            selectedProject = project
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func closeRepo() {
        activeRepo = nil
        workspace = nil
        selectedProject = nil
        board = nil
        source = nil
        isDemo = false
        clearFilters()
    }

    // MARK: - Writes (over the provider API via git-pont)

    func createTask(
        title rawTitle: String, lane: Lane,
        priority: String?, type: String?, assignee: String?, body: String
    ) async {
        let title = rawTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let source, let project = selectedProject, !title.isEmpty, !lane.folder.isEmpty else { return }
        let id = uniqueID(for: title, lane: lane)
        let path = "\(project.folder)/\(lane.folder)/\(id).md"
        let content = CardText.make(
            id: id, title: title, project: project.name, status: lane.status,
            priority: priority, type: type, assignee: assignee, body: body
        )
        await performWrite { try await source.write(path: path, text: content, message: "Add task \(id)") }
    }

    func moveCard(_ card: Card, to lane: Lane) async {
        guard let source, let project = selectedProject,
              let location = location(of: card), let fileName = card.fileName,
              location.lane.id != lane.id, !lane.folder.isEmpty else { return }
        let original = (try? await source.readText(location.path)) ?? card.body
        let updated = CardText.update(original, set: ["status": lane.status])
        let newPath = "\(project.folder)/\(lane.folder)/\(fileName)"
        let message = "Move \(card.fields.id) to \(lane.name)"
        await performWrite {
            try await source.write(path: newPath, text: updated, message: message)
            try await source.delete(path: location.path, message: message)
        }
    }

    func updateCard(
        _ card: Card, title: String, laneID: String,
        priority: String, type: String, assignee: String, body: String
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
