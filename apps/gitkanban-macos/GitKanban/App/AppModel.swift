import AppKit
import Foundation
import GitKit
import Observation

/// How the board renders the selected project.
enum BoardViewMode: String, CaseIterable, Identifiable {
    case lanes
    case list
    var id: String { rawValue }
}

/// Where the backlog docks alongside the lanes.
enum BacklogPlacement: String, CaseIterable, Identifiable {
    case bottom
    case right
    var id: String { rawValue }
}

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
    /// True until the initial session restore finishes (show a loader, not a flash
    /// through Connect → RepoPicker → Workspace).
    var isRestoring = true

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
    /// When set, the New Task sheet is shown, pre-selecting this lane.
    var newTaskLane: Lane?
    var isCreatingTask = false
    /// When set, the Project Settings sheet is shown for this project.
    var settingsProject: BoardProject?
    /// The card currently being dragged (hidden in its lane while dragging).
    var draggingCardID: String?
    /// How the board is laid out: horizontal lanes (kanban) or a grouped list.
    var boardViewMode: BoardViewMode = .lanes
    /// Where the backlog docks relative to the lanes.
    var backlogPlacement: BacklogPlacement = .bottom
    /// Cards multi-selected via ⌘-click, for bulk actions from the context menu.
    var selectedCardIDs: Set<String> = []

    // MARK: State — filters + search
    var filterAssignee: String?
    var filterPriority: String?
    var filterType: String?
    /// Whether the search sheet is shown.
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

    /// Whether a card passes the active board filters.
    func matchesFilters(_ card: Card) -> Bool {
        if let filterAssignee, card.fields.assignee != filterAssignee { return false }
        if let filterPriority, card.fields.priority != filterPriority { return false }
        if let filterType, card.fields.type != filterType { return false }
        return true
    }

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

    /// Every card on the current board (all lanes + uncategorised).
    var allCards: [Card] { (board?.columns.flatMap(\.cards) ?? []) + (board?.uncategorised ?? []) }

    // MARK: - Lifecycle

    /// Load a stored token from the keychain and, if present, restore the session.
    func restore() async {
        defer { isRestoring = false }
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
                if hasCommits(at: dir) {
                    syncStatus = "Pulling…"
                    _ = try await git.pullRebase(at: dir, auth: auth)
                } else {
                    // Local branch is unborn; adopt the remote's commits if it has any.
                    syncStatus = "Syncing…"
                    syncUnbornFromRemote(at: dir, branch: repo.defaultBranch)
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
        draggingCardID = nil
        selectedCardIDs.removeAll()
        clearFilters()
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

    /// Create a task (card) in the given lane of the current project: write a new
    /// markdown card, commit, and push. Reloads the board on success.
    func createTask(
        title rawTitle: String,
        lane: Lane,
        priority: String?,
        type: String?,
        assignee: String?,
        body: String
    ) async {
        let title = rawTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let checkoutURL, let project = selectedProject else {
            errorMessage = "Open a project before creating a task."
            return
        }
        guard !title.isEmpty else { errorMessage = "A task needs a title."; return }
        guard !lane.folder.isEmpty else { errorMessage = "Pick a lane for the task."; return }

        isCreatingTask = true
        errorMessage = nil
        defer { isCreatingTask = false }

        let laneURL = checkoutURL
            .appendingPathComponent(project.folder, isDirectory: true)
            .appendingPathComponent(lane.folder, isDirectory: true)
        let fileName = uniqueCardFileName(for: title, in: laneURL)
        let id = (fileName as NSString).deletingPathExtension

        var front = "---\n"
        front += "id: \(id)\n"
        front += "title: \(yamlScalar(title))\n"
        front += "project: \(yamlScalar(project.name))\n"
        front += "status: \(lane.status)\n"
        if let priority, !priority.isEmpty { front += "priority: \(priority)\n" }
        if let type, !type.isEmpty { front += "type: \(yamlScalar(type))\n" }
        if let assignee, !assignee.isEmpty { front += "assignee: \(yamlScalar(assignee))\n" }
        front += "---\n\n"
        let content = front + body.trimmingCharacters(in: .whitespacesAndNewlines) + "\n"

        do {
            try FileManager.default.createDirectory(at: laneURL, withIntermediateDirectories: true)
            try content.write(to: laneURL.appendingPathComponent(fileName), atomically: true, encoding: .utf8)

            let relative = "\(project.folder)/\(lane.folder)/\(fileName)"
            syncStatus = "Creating task…"
            if hasCommits(at: checkoutURL) {
                _ = try? await git.pullRebase(at: checkoutURL, auth: auth)
            }
            try await git.commit(at: checkoutURL, message: "Add task \(id)", paths: [relative])
            syncStatus = "Pushing…"
            try await git.push(at: checkoutURL, auth: auth)
            syncStatus = "Pushed"
        } catch {
            syncStatus = "Error"
            errorMessage = error.localizedDescription
        }

        if let project = selectedProject { selectProject(project) }
    }

    private func uniqueCardFileName(for title: String, in laneURL: URL) -> String {
        let base = slug(title).isEmpty ? "task" : slug(title)
        var name = "\(base).md"
        var n = 2
        while FileManager.default.fileExists(atPath: laneURL.appendingPathComponent(name).path) {
            name = "\(base)-\(n).md"; n += 1
        }
        return name
    }

    private func slug(_ s: String) -> String {
        let mapped = s.lowercased().map { ($0.isLetter || $0.isNumber) ? $0 : "-" }
        var result = String(mapped)
        while result.contains("--") { result = result.replacingOccurrences(of: "--", with: "-") }
        return result.trimmingCharacters(in: CharacterSet(charactersIn: "-"))
    }

    private func yamlScalar(_ s: String) -> String {
        if s.isEmpty { return "\"\"" }
        let needsQuote = s.contains(":") || s.contains("#") || s.first == " " || s.last == " "
        return needsQuote ? "\"\(s.replacingOccurrences(of: "\"", with: "\\\""))\"" : s
    }

    /// Move a card to another lane: move its file into the new lane folder, update
    /// its `status` frontmatter, then commit + push. Reloads the board.
    func moveCard(cardID: String, to lane: Lane) async {
        guard let checkoutURL, let project = selectedProject, var board else { return }
        guard let sourceIndex = board.columns.firstIndex(where: { col in
            col.cards.contains { $0.fields.id == cardID }
        }),
        let cardIndex = board.columns[sourceIndex].cards.firstIndex(where: { $0.fields.id == cardID }),
        let targetIndex = board.columns.firstIndex(where: { $0.lane.id == lane.id }) else { return }
        let sourceLane = board.columns[sourceIndex].lane
        guard sourceLane.id != lane.id, !lane.folder.isEmpty else { return }
        var card = board.columns[sourceIndex].cards[cardIndex]
        guard let fileName = card.fileName else { return }

        // Optimistic UI: move the card between columns right away.
        draggingCardID = nil
        errorMessage = nil
        card.fields.status = lane.status
        board.columns[sourceIndex].cards.remove(at: cardIndex)
        board.columns[targetIndex].cards.append(card)
        self.board = board

        let base = checkoutURL.appendingPathComponent(project.folder, isDirectory: true)
        let sourceURL = base.appendingPathComponent(sourceLane.folder).appendingPathComponent(fileName)
        let targetDir = base.appendingPathComponent(lane.folder, isDirectory: true)
        let targetURL = targetDir.appendingPathComponent(fileName)

        do {
            try FileManager.default.createDirectory(at: targetDir, withIntermediateDirectories: true)
            let original = (try? String(contentsOf: sourceURL, encoding: .utf8)) ?? card.body
            try updatingStatus(in: original, to: lane.status).write(to: targetURL, atomically: true, encoding: .utf8)
            if targetURL.path != sourceURL.path { try? FileManager.default.removeItem(at: sourceURL) }

            let sourceRel = "\(project.folder)/\(sourceLane.folder)/\(fileName)"
            let targetRel = "\(project.folder)/\(lane.folder)/\(fileName)"
            syncStatus = "Moving…"
            if hasCommits(at: checkoutURL) { _ = try? await git.pullRebase(at: checkoutURL, auth: auth) }
            try await git.commit(at: checkoutURL, message: "Move \(cardID) to \(lane.name)", paths: [sourceRel, targetRel])
            syncStatus = "Pushing…"
            try await git.push(at: checkoutURL, auth: auth)
            syncStatus = "Pushed"
        } catch {
            syncStatus = "Error"
            errorMessage = error.localizedDescription
            // Revert the optimistic move by reloading from disk.
            if let project = selectedProject { selectProject(project) }
        }
    }

    /// Replace the first `status:` line inside the frontmatter with a new value.
    private func updatingStatus(in content: String, to status: String) -> String {
        var lines = content.components(separatedBy: "\n")
        var inFrontmatter = false
        for index in lines.indices {
            let trimmed = lines[index].trimmingCharacters(in: .whitespaces)
            if trimmed == "---" {
                if inFrontmatter { break }   // end of frontmatter
                inFrontmatter = true
                continue
            }
            if inFrontmatter, lines[index].hasPrefix("status:") {
                lines[index] = "status: \(status)"
                break
            }
        }
        return lines.joined(separator: "\n")
    }

    /// Delete a card: remove its file, then commit + push. Reloads the board.
    func deleteCard(cardID: String) async {
        guard let checkoutURL, let project = selectedProject, let board else { return }
        guard let column = board.columns.first(where: { c in c.cards.contains { $0.fields.id == cardID } }),
              let card = column.cards.first(where: { $0.fields.id == cardID }),
              let fileName = card.fileName else { return }
        errorMessage = nil
        let relative = "\(project.folder)/\(column.lane.folder)/\(fileName)"
        do {
            try? FileManager.default.removeItem(at: checkoutURL.appendingPathComponent(relative))
            syncStatus = "Deleting…"
            if hasCommits(at: checkoutURL) { _ = try? await git.pullRebase(at: checkoutURL, auth: auth) }
            try await git.commit(at: checkoutURL, message: "Delete \(cardID)", paths: [relative])
            syncStatus = "Pushing…"
            try await git.push(at: checkoutURL, auth: auth)
            syncStatus = "Pushed"
        } catch {
            syncStatus = "Error"
            errorMessage = error.localizedDescription
        }
        if let project = selectedProject { selectProject(project) }
    }

    // MARK: - Multi-selection + bulk actions

    /// Toggle a card in/out of the multi-selection (⌘-click).
    func toggleSelection(_ id: String) {
        if selectedCardIDs.contains(id) { selectedCardIDs.remove(id) } else { selectedCardIDs.insert(id) }
    }

    func clearSelection() { selectedCardIDs.removeAll() }

    /// Move several cards into `lane` in a single commit: move each file, update its
    /// `status` frontmatter, then commit + push once. Reloads the board.
    func moveCards(ids: [String], to lane: Lane) async {
        guard let checkoutURL, let project = selectedProject, let board else {
            errorMessage = "Open a project before moving tasks."
            return
        }
        guard !lane.folder.isEmpty else { return }
        errorMessage = nil

        let base = checkoutURL.appendingPathComponent(project.folder, isDirectory: true)
        let targetDir = base.appendingPathComponent(lane.folder, isDirectory: true)
        var paths: [String] = []
        var moved = 0

        do {
            try FileManager.default.createDirectory(at: targetDir, withIntermediateDirectories: true)
            for id in ids {
                guard let column = board.columns.first(where: { c in c.cards.contains { $0.fields.id == id } }),
                      let card = column.cards.first(where: { $0.fields.id == id }),
                      let fileName = card.fileName else { continue }
                let sourceLane = column.lane
                guard sourceLane.id != lane.id else { continue }
                let sourceURL = base.appendingPathComponent(sourceLane.folder).appendingPathComponent(fileName)
                let targetURL = targetDir.appendingPathComponent(fileName)
                let original = (try? String(contentsOf: sourceURL, encoding: .utf8)) ?? card.body
                try updatingStatus(in: original, to: lane.status).write(to: targetURL, atomically: true, encoding: .utf8)
                if targetURL.path != sourceURL.path { try? FileManager.default.removeItem(at: sourceURL) }
                paths.append("\(project.folder)/\(sourceLane.folder)/\(fileName)")
                paths.append("\(project.folder)/\(lane.folder)/\(fileName)")
                moved += 1
            }
            guard moved > 0 else { clearSelection(); return }

            syncStatus = "Moving…"
            if hasCommits(at: checkoutURL) { _ = try? await git.pullRebase(at: checkoutURL, auth: auth) }
            try await git.commit(at: checkoutURL, message: "Move \(moved) tasks to \(lane.name)", paths: paths)
            syncStatus = "Pushing…"
            try await git.push(at: checkoutURL, auth: auth)
            syncStatus = "Pushed"
        } catch {
            syncStatus = "Error"
            errorMessage = error.localizedDescription
        }

        clearSelection()
        if let project = selectedProject { selectProject(project) }
    }

    /// Delete several cards in a single commit. Reloads the board.
    func deleteCards(ids: [String]) async {
        guard let checkoutURL, let project = selectedProject, let board else { return }
        errorMessage = nil
        var paths: [String] = []
        for id in ids {
            guard let column = board.columns.first(where: { c in c.cards.contains { $0.fields.id == id } }),
                  let card = column.cards.first(where: { $0.fields.id == id }),
                  let fileName = card.fileName else { continue }
            let relative = "\(project.folder)/\(column.lane.folder)/\(fileName)"
            try? FileManager.default.removeItem(at: checkoutURL.appendingPathComponent(relative))
            paths.append(relative)
        }
        guard !paths.isEmpty else { clearSelection(); return }
        do {
            syncStatus = "Deleting…"
            if hasCommits(at: checkoutURL) { _ = try? await git.pullRebase(at: checkoutURL, auth: auth) }
            try await git.commit(at: checkoutURL, message: "Delete \(paths.count) tasks", paths: paths)
            syncStatus = "Pushing…"
            try await git.push(at: checkoutURL, auth: auth)
            syncStatus = "Pushed"
        } catch {
            syncStatus = "Error"
            errorMessage = error.localizedDescription
        }
        clearSelection()
        if let project = selectedProject { selectProject(project) }
    }

    func toggleBacklogPlacement() {
        backlogPlacement = backlogPlacement == .bottom ? .right : .bottom
    }

    // MARK: - Ordering + assignment

    /// Move a card into `lane` positioned before `beforeCardID` (or at the end when
    /// nil), rewriting the `order` frontmatter of every affected card so the new
    /// arrangement persists. Handles both same-lane reordering and cross-lane moves
    /// (updating `status` and renumbering the source lane) in a single commit.
    func reorderCard(cardID: String, toLane lane: Lane, beforeCardID: String?) async {
        guard let checkoutURL, let project = selectedProject, let board else { return }
        guard !lane.folder.isEmpty else { return }
        guard cardID != beforeCardID else { draggingCardID = nil; return }
        guard let srcColIdx = board.columns.firstIndex(where: { $0.cards.contains { $0.fields.id == cardID } }),
              let dstColIdx = board.columns.firstIndex(where: { $0.lane.id == lane.id }) else { return }
        let sourceLane = board.columns[srcColIdx].lane
        guard let dragged = board.columns[srcColIdx].cards.first(where: { $0.fields.id == cardID }),
              dragged.fileName != nil else { return }
        let sameLane = sourceLane.id == lane.id

        // The destination lane's new order, with the dragged card inserted.
        var destCards = board.columns[dstColIdx].cards
        destCards.removeAll { $0.fields.id == cardID }
        let insertAt: Int
        if let beforeCardID, let idx = destCards.firstIndex(where: { $0.fields.id == beforeCardID }) {
            insertAt = idx
        } else {
            insertAt = destCards.count
        }
        destCards.insert(dragged, at: insertAt)

        let base = checkoutURL.appendingPathComponent(project.folder, isDirectory: true)
        let destDir = base.appendingPathComponent(lane.folder, isDirectory: true)

        errorMessage = nil
        var paths: [String] = []
        do {
            try FileManager.default.createDirectory(at: destDir, withIntermediateDirectories: true)

            for (index, card) in destCards.enumerated() {
                guard let fileName = card.fileName else { continue }
                let order = index + 1
                let destURL = destDir.appendingPathComponent(fileName)

                if card.fields.id == cardID && !sameLane {
                    let srcURL = base.appendingPathComponent(sourceLane.folder).appendingPathComponent(fileName)
                    let original = (try? String(contentsOf: srcURL, encoding: .utf8)) ?? card.body
                    let composed = composeFrontmatter(original, ["status": lane.status, "order": "\(order)"])
                    try composed.write(to: destURL, atomically: true, encoding: .utf8)
                    if destURL.path != srcURL.path { try? FileManager.default.removeItem(at: srcURL) }
                    paths.append("\(project.folder)/\(sourceLane.folder)/\(fileName)")
                    paths.append("\(project.folder)/\(lane.folder)/\(fileName)")
                } else {
                    try applyFrontmatter(to: destURL, ["order": "\(order)"])
                    paths.append("\(project.folder)/\(lane.folder)/\(fileName)")
                }
            }

            if !sameLane {
                let remaining = board.columns[srcColIdx].cards.filter { $0.fields.id != cardID }
                for (index, card) in remaining.enumerated() {
                    guard let fileName = card.fileName else { continue }
                    let url = base.appendingPathComponent(sourceLane.folder).appendingPathComponent(fileName)
                    try applyFrontmatter(to: url, ["order": "\(index + 1)"])
                    paths.append("\(project.folder)/\(sourceLane.folder)/\(fileName)")
                }
            }

            syncStatus = sameLane ? "Reordering…" : "Moving…"
            if hasCommits(at: checkoutURL) { _ = try? await git.pullRebase(at: checkoutURL, auth: auth) }
            let message = sameLane ? "Reorder \(cardID)" : "Move \(cardID) to \(lane.name)"
            try await git.commit(at: checkoutURL, message: message, paths: Array(Set(paths)))
            syncStatus = "Pushing…"
            try await git.push(at: checkoutURL, auth: auth)
            syncStatus = "Pushed"
        } catch {
            syncStatus = "Error"
            errorMessage = error.localizedDescription
        }

        draggingCardID = nil
        if let project = selectedProject { selectProject(project) }
    }

    /// Assign (or unassign, with a nil/empty value) several cards in one commit.
    func assignCards(ids: [String], assignee: String?) async {
        guard let checkoutURL, let project = selectedProject, let board else { return }
        errorMessage = nil
        let value = (assignee?.isEmpty == false) ? assignee : nil
        var paths: [String] = []
        for id in ids {
            guard let column = board.columns.first(where: { c in c.cards.contains { $0.fields.id == id } }),
                  let card = column.cards.first(where: { $0.fields.id == id }),
                  let fileName = card.fileName else { continue }
            let url = checkoutURL
                .appendingPathComponent(project.folder, isDirectory: true)
                .appendingPathComponent(column.lane.folder)
                .appendingPathComponent(fileName)
            try? applyFrontmatter(to: url, ["assignee": value])
            paths.append("\(project.folder)/\(column.lane.folder)/\(fileName)")
        }
        guard !paths.isEmpty else { clearSelection(); return }
        do {
            syncStatus = "Assigning…"
            if hasCommits(at: checkoutURL) { _ = try? await git.pullRebase(at: checkoutURL, auth: auth) }
            let who = value ?? "no one"
            try await git.commit(at: checkoutURL, message: "Assign \(paths.count) tasks to \(who)", paths: paths)
            syncStatus = "Pushing…"
            try await git.push(at: checkoutURL, auth: auth)
            syncStatus = "Pushed"
        } catch {
            syncStatus = "Error"
            errorMessage = error.localizedDescription
        }
        clearSelection()
        if let project = selectedProject { selectProject(project) }
    }

    /// Update `updates` (nil removes a key) in a card file's frontmatter, preserving
    /// its body and any other keys.
    private func applyFrontmatter(to url: URL, _ updates: [String: String?]) throws {
        let original = (try? String(contentsOf: url, encoding: .utf8)) ?? ""
        try composeFrontmatter(original, updates).write(to: url, atomically: true, encoding: .utf8)
    }

    /// Return `original` with `updates` applied to its frontmatter (nil removes a key),
    /// body untouched.
    private func composeFrontmatter(_ original: String, _ updates: [String: String?]) -> String {
        let (frontmatter, body) = BoardMarkdown.splitFrontmatter(original)
        var lines = (frontmatter ?? "").components(separatedBy: "\n")
        for (key, value) in updates {
            lines = setFrontmatterKey(lines, key, value.flatMap { $0.isEmpty ? nil : $0 })
        }
        let fm = lines
            .filter { !$0.trimmingCharacters(in: .whitespaces).isEmpty }
            .joined(separator: "\n")
        let trimmedBody = body.trimmingCharacters(in: .whitespacesAndNewlines)
        return "---\n\(fm)\n---\n\n\(trimmedBody)\n"
    }

    /// Count tasks assigned to a given user in the current board (for the
    /// "removing this member affects N tasks" prompt).
    func taskCount(assignedTo userID: String) -> Int {
        allCards.filter { $0.fields.assignee == userID }.count
    }

    /// Save edited project settings: rewrite the project's `README.md` config,
    /// unassign tasks of removed members, then commit + push and reload.
    func saveProjectSettings(
        project: BoardProject,
        name: String,
        description: String,
        lanes: [Lane],
        priorities: [Priority],
        users: [User],
        types: [String],
        unassign: Set<String>
    ) async {
        guard let checkoutURL else { return }
        errorMessage = nil
        let projectURL = checkoutURL.appendingPathComponent(project.folder, isDirectory: true)
        do {
            let readme = BoardStore.renderProjectReadme(
                name: name, description: description, lanes: lanes,
                priorities: priorities, users: users, types: types
            )
            try readme.write(to: projectURL.appendingPathComponent("README.md"), atomically: true, encoding: .utf8)
            if !unassign.isEmpty { unassignTasks(in: projectURL, lanes: lanes, members: unassign) }

            syncStatus = "Saving settings…"
            if hasCommits(at: checkoutURL) { _ = try? await git.pullRebase(at: checkoutURL, auth: auth) }
            try await git.commit(at: checkoutURL, message: "Update \(name) settings", paths: [project.folder])
            syncStatus = "Pushing…"
            try await git.push(at: checkoutURL, auth: auth)
            syncStatus = "Pushed"
        } catch {
            syncStatus = "Error"
            errorMessage = error.localizedDescription
        }
        do {
            workspace = try BoardStore.loadWorkspace(at: checkoutURL)
            if let updated = workspace?.projects.first(where: { $0.folder == project.folder }) {
                selectProject(updated)
            }
        } catch { errorMessage = error.localizedDescription }
    }

    /// Remove the `assignee` frontmatter line from any card assigned to a removed member.
    private func unassignTasks(in projectURL: URL, lanes: [Lane], members: Set<String>) {
        for lane in lanes where !lane.folder.isEmpty {
            let laneURL = projectURL.appendingPathComponent(lane.folder, isDirectory: true)
            let files = (try? FileManager.default.contentsOfDirectory(atPath: laneURL.path)) ?? []
            for file in files where file.hasSuffix(".md") {
                let url = laneURL.appendingPathComponent(file)
                guard var content = try? String(contentsOf: url, encoding: .utf8) else { continue }
                var lines = content.components(separatedBy: "\n")
                var inFront = false
                var changed = false
                lines = lines.filter { line in
                    let trimmed = line.trimmingCharacters(in: .whitespaces)
                    if trimmed == "---" { inFront.toggle(); return true }
                    if inFront, line.hasPrefix("assignee:") {
                        let value = String(line.dropFirst("assignee:".count)).trimmingCharacters(in: .whitespaces)
                        if members.contains(value) { changed = true; return false }
                    }
                    return true
                }
                if changed {
                    content = lines.joined(separator: "\n")
                    try? content.write(to: url, atomically: true, encoding: .utf8)
                }
            }
        }
    }

    /// Reveal a project's folder in Finder.
    func revealInFinder(_ project: BoardProject) {
        guard let checkoutURL else { return }
        NSWorkspace.shared.activateFileViewerSelecting([
            checkoutURL.appendingPathComponent(project.folder, isDirectory: true)
        ])
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

    /// The github.com blob URL for a card's file (Find on GitHub).
    func githubURL(for card: Card) -> URL? {
        guard let repo = activeRepo, let relative = relativePath(for: card) else { return nil }
        let encoded = relative.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? relative
        return URL(string: "https://github.com/\(repo.fullName)/blob/\(repo.defaultBranch)/\(encoded)")
    }

    /// The commit history of a card's file (for the History window).
    func fileHistory(for card: Card) async -> [CommitInfo] {
        guard let checkoutURL, let relative = relativePath(for: card) else { return [] }
        return (try? await git.fileHistory(at: checkoutURL, file: relative, limit: 50)) ?? []
    }

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

    /// Save structured field edits from the card editor: rewrite the file's
    /// frontmatter (preserving any keys the editor doesn't model), replace the body,
    /// and — if `targetLane` differs from the card's current lane — move the file into
    /// the new lane's folder. Commits + pushes, then reloads the board.
    func updateCard(_ card: Card, fields: CardFields, body: String, targetLane: Lane) async {
        guard let checkoutURL, let project = selectedProject, let board else {
            errorMessage = "Open a project before editing a task."
            return
        }
        guard let fileName = card.fileName,
              let column = board.columns.first(where: { col in
                  col.cards.contains { $0.fields.id == card.fields.id }
              }) else {
            errorMessage = "This card has no file on disk to save to."
            return
        }
        let sourceLane = column.lane
        let base = checkoutURL.appendingPathComponent(project.folder, isDirectory: true)
        let sourceURL = base.appendingPathComponent(sourceLane.folder).appendingPathComponent(fileName)

        // Compose from the on-disk text so unmodelled frontmatter is preserved.
        let original = (try? String(contentsOf: sourceURL, encoding: .utf8)) ?? card.body
        let composed = composeCard(original: original, fields: fields, status: targetLane.status, body: body)

        let moved = targetLane.id != sourceLane.id && !targetLane.folder.isEmpty
        let targetDir = moved
            ? base.appendingPathComponent(targetLane.folder, isDirectory: true)
            : sourceURL.deletingLastPathComponent()
        let targetURL = targetDir.appendingPathComponent(fileName)

        let sourceRel = "\(project.folder)/\(sourceLane.folder)/\(fileName)"
        let targetRel = "\(project.folder)/\(targetLane.folder)/\(fileName)"

        errorMessage = nil
        do {
            try FileManager.default.createDirectory(at: targetDir, withIntermediateDirectories: true)
            try composed.write(to: targetURL, atomically: true, encoding: .utf8)
            if moved, targetURL.path != sourceURL.path {
                try? FileManager.default.removeItem(at: sourceURL)
            }

            syncStatus = "Committing…"
            if hasCommits(at: checkoutURL) { _ = try? await git.pullRebase(at: checkoutURL, auth: auth) }
            let paths = moved ? [sourceRel, targetRel] : [sourceRel]
            try await git.commit(at: checkoutURL, message: "Update \(card.fields.id)", paths: paths)
            syncStatus = "Pushing…"
            try await git.push(at: checkoutURL, auth: auth)
            syncStatus = "Pushed"
        } catch {
            syncStatus = "Error"
            errorMessage = error.localizedDescription
        }

        if let project = selectedProject { selectProject(project) }
    }

    /// Rebuild a card file from `original`, updating the modelled frontmatter keys
    /// (leaving any others in place) and replacing the body. `status` comes from the
    /// target lane, not `fields`, so a lane change is reflected in the frontmatter.
    private func composeCard(original: String, fields: CardFields, status: String, body: String) -> String {
        let (frontmatter, _) = BoardMarkdown.splitFrontmatter(original)
        var lines = (frontmatter ?? "").components(separatedBy: "\n")

        lines = setFrontmatterKey(lines, "id", fields.id.isEmpty ? nil : fields.id)
        lines = setFrontmatterKey(lines, "title", fields.title.isEmpty ? nil : yamlScalar(fields.title))
        lines = setFrontmatterKey(lines, "project", fields.project.isEmpty ? nil : yamlScalar(fields.project))
        lines = setFrontmatterKey(lines, "status", status.isEmpty ? nil : status)
        lines = setFrontmatterKey(lines, "priority", fields.priority)
        lines = setFrontmatterKey(lines, "type", fields.type.map(yamlScalar))
        lines = setFrontmatterKey(lines, "assignee", fields.assignee.map(yamlScalar))
        lines = setFrontmatterKey(lines, "order", fields.order)

        let fm = lines
            .filter { !$0.trimmingCharacters(in: .whitespaces).isEmpty }
            .joined(separator: "\n")
        let trimmedBody = body.trimmingCharacters(in: .whitespacesAndNewlines)
        return "---\n\(fm)\n---\n\n\(trimmedBody)\n"
    }

    /// Replace the top-level `key:` line in `lines` with `key: value`, appending it
    /// when absent. A nil/empty value removes the line. Nested (indented) keys are
    /// left untouched.
    private func setFrontmatterKey(_ lines: [String], _ key: String, _ value: String?) -> [String] {
        var result = lines
        let index = result.firstIndex { isTopLevelKeyLine($0, key) }
        if let value, !value.isEmpty {
            let line = "\(key): \(value)"
            if let index { result[index] = line } else { result.append(line) }
        } else if let index {
            result.remove(at: index)
        }
        return result
    }

    private func isTopLevelKeyLine(_ line: String, _ key: String) -> Bool {
        guard let first = line.first, !first.isWhitespace else { return false }
        guard let colon = line.firstIndex(of: ":") else { return false }
        return line[line.startIndex..<colon].trimmingCharacters(in: .whitespaces) == key
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

    /// Fetch the remote and, if it has commits on `branch`, adopt them into the
    /// (unborn) local branch. Used when a repo was cloned empty and later got content.
    private func syncUnbornFromRemote(at dir: URL, branch: String) {
        let basic = Data("\(login ?? "x-access-token"):\(token ?? "")".utf8).base64EncodedString()
        let header = "http.extraheader=AUTHORIZATION: basic \(basic)"
        _ = try? runner.run(["-c", header, "fetch", "origin"], in: dir)
        if let result = try? runner.run(["rev-parse", "--verify", "--quiet", "origin/\(branch)"], in: dir),
           result.exitCode == 0 {
            _ = try? runner.run(["reset", "--hard", "origin/\(branch)"], in: dir)
            _ = try? runner.run(["branch", "--set-upstream-to=origin/\(branch)", branch], in: dir)
        }
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
