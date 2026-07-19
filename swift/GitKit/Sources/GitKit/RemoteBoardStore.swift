import Foundation

/// An async, transport-agnostic source of repository files. It lets board loading
/// work without a local checkout — iOS feeds it a GitHub-API-backed source (git-pont),
/// macOS could feed it a disk-backed one — so the same board logic runs everywhere.
///
/// Paths are repo-relative and use forward slashes; the repo root is `""`.
public protocol BoardFileSource: Sendable {
    /// The immediate entries under a repo-relative directory (`""` = repo root).
    func list(_ directory: String) async throws -> [BoardFileEntry]
    /// A repo-relative file decoded as UTF-8 text.
    func readText(_ path: String) async throws -> String
}

/// One entry in a `BoardFileSource` directory listing.
public struct BoardFileEntry: Sendable, Equatable {
    public enum Kind: Sendable, Equatable { case file, directory }
    public let name: String
    public let path: String
    public let kind: Kind

    public init(name: String, path: String, kind: Kind) {
        self.name = name
        self.path = path
        self.kind = kind
    }
}

/// Loads a workspace and project boards through a `BoardFileSource`, mirroring
/// `BoardStore`'s on-disk loaders (`loadWorkspace` / `loadProjectBoard`) but over any
/// async transport. Card parsing, config inheritance and lane sorting are the exact
/// shared `BoardStore` logic, so a board renders identically to the macOS app.
public enum RemoteBoardStore {

    /// Load the workspace. Handles flexible layouts:
    /// - **Direct board:** lanes at the repo root (root README has `lanes`) → one project.
    /// - **Multi-project:** top-level folders that each contain a `README.md`.
    /// - **Nested:** projects under organisational folders at any depth (e.g.
    ///   `project-assets/Tasks/<project>`), found by recursing into folders that only
    ///   contain other project/container folders (not lane folders).
    public static func loadWorkspace(source: BoardFileSource) async throws -> Workspace {
        let rootConfig = (try? await loadBoardConfig(source: source, dir: "")) ?? BoardConfig()
        let rootEntries = (try? await source.list("")) ?? []
        let rootLaneFolders = Set(rootConfig.lanes.map(\.folder))

        // Direct board: the repo root itself holds the lane folders (not sub-projects).
        if !rootConfig.lanes.isEmpty,
           rootEntries.contains(where: { $0.kind == .directory && rootLaneFolders.contains($0.name) }) {
            let project = BoardProject(id: "", name: "Board", folder: "", config: ProjectConfig())
            return Workspace(rootConfig: rootConfig, projects: [project])
        }

        var projects = await discoverProjects(source: source, dir: "", inheritedLanes: rootConfig.lanes, depth: 0)
        projects.sort { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
        return Workspace(rootConfig: rootConfig, projects: projects)
    }

    /// Recursively find project folders. A directory is a **project** when its README
    /// carries a project marker (`project:`), or it actually contains the lane folders
    /// of the effective config. Other folders (organisational, e.g. `project-assets/`
    /// or a `Tasks/` root holding per-project folders) are recursed into so boards at
    /// any depth are found — without misreading a lane folder as a project.
    private static func discoverProjects(
        source: BoardFileSource, dir: String, inheritedLanes: [Lane], depth: Int
    ) async -> [BoardProject] {
        guard depth <= 4 else { return [] }
        let entries = (try? await source.list(dir)) ?? []
        let inheritedFolders = Set(inheritedLanes.map(\.folder))
        var found: [BoardProject] = []

        for entry in entries where entry.kind == .directory {
            let name = entry.name
            guard !name.hasPrefix("."), name != "node_modules" else { continue }
            if inheritedFolders.contains(name) { continue }  // a lane folder of this board

            let projectConfig = (try? await loadProjectConfig(source: source, dir: entry.path)) ?? ProjectConfig()
            let ownBoard = (try? await loadBoardConfig(source: source, dir: entry.path)) ?? BoardConfig()
            let lanes = ownBoard.lanes.isEmpty ? inheritedLanes : ownBoard.lanes
            let laneFolders = Set(lanes.map(\.folder))
            let children = (try? await source.list(entry.path)) ?? []
            let hasLaneFolders = children.contains { $0.kind == .directory && laneFolders.contains($0.name) }

            if projectConfig.project != nil || hasLaneFolders {
                let display = projectConfig.project?.isEmpty == false ? projectConfig.project! : name
                found.append(BoardProject(id: entry.path, name: display, folder: entry.path, config: projectConfig))
            } else {
                found += await discoverProjects(source: source, dir: entry.path, inheritedLanes: lanes, depth: depth + 1)
            }
        }
        return found
    }

    /// Resolve and load one project's board. Cards are read from each lane's folder
    /// (the lane is known from the folder, not the card `status`) and sorted the same
    /// way the disk loader sorts them. Non-lane subfolders become `uncategorised`.
    public static func loadProjectBoard(
        source: BoardFileSource,
        project: BoardProject,
        rootConfig: BoardConfig,
        loadBacklog: Bool = true
    ) async throws -> LoadedBoard {
        let effective = resolveEffectiveConfig(rootConfig, project.config)
        let laneFolders = Set(effective.lanes.map(\.folder))

        // Load all lanes concurrently (each lane's cards also load concurrently), so a
        // board over the API isn't gated on sequential per-file round-trips. Backlog
        // lanes are skipped unless requested — they can be large and load on demand.
        let columns = try await withThrowingTaskGroup(of: (Int, Column).self) { group -> [Column] in
            for (index, lane) in effective.lanes.enumerated() {
                group.addTask {
                    guard loadBacklog || !lane.isBacklog else {
                        return (index, Column(lane: lane, cards: []))
                    }
                    let cards = try await loadCards(
                        source: source,
                        dir: join(project.folder, lane.folder),
                        fieldSource: effective.fieldSource
                    )
                    return (index, Column(lane: lane, cards: BoardStore.sortedCards(cards, config: effective)))
                }
            }
            var results: [(Int, Column)] = []
            for try await pair in group { results.append(pair) }
            return results.sorted { $0.0 < $1.0 }.map(\.1)
        }

        var uncategorised: [Card] = []
        let subEntries = (try? await source.list(project.folder)) ?? []
        for entry in subEntries where entry.kind == .directory {
            guard !entry.name.hasPrefix("."), !laneFolders.contains(entry.name), entry.name != "attachments" else { continue }
            uncategorised += try await loadCards(source: source, dir: entry.path, fieldSource: effective.fieldSource)
        }

        return LoadedBoard(config: effective, columns: columns, uncategorised: uncategorised)
    }

    /// Open a specific board by its project folder (`""` = the repo root board), without
    /// a full workspace scan. Returns the project, the root config it inherits from, and
    /// the loaded board. `folder` is relative to the source root.
    public static func loadBoard(
        source: BoardFileSource, folder: String, loadBacklog: Bool = false
    ) async throws -> (project: BoardProject, rootConfig: BoardConfig, board: LoadedBoard) {
        let rootConfig = (try? await loadBoardConfig(source: source, dir: "")) ?? BoardConfig()
        let projectConfig = (try? await loadProjectConfig(source: source, dir: folder)) ?? ProjectConfig()
        let fallback = folder.split(separator: "/").last.map(String.init) ?? "Board"
        let name = projectConfig.project?.isEmpty == false ? projectConfig.project! : fallback
        let project = BoardProject(id: folder, name: name, folder: folder, config: projectConfig)
        let board = try await loadProjectBoard(source: source, project: project, rootConfig: rootConfig, loadBacklog: loadBacklog)
        return (project, rootConfig, board)
    }

    /// Load the cards in a directory (no config needed) — used to auto-detect a board's
    /// structure from its folders and card fields.
    public static func cards(source: BoardFileSource, dir: String) async throws -> [Card] {
        try await loadCards(source: source, dir: dir, fieldSource: nil)
    }

    /// Count the cards in a board without reading their contents — just list each lane
    /// folder and count card files. Used for the boards list's "N tasks" summary.
    public static func taskCount(source: BoardFileSource, folder: String) async throws -> Int {
        let rootConfig = (try? await loadBoardConfig(source: source, dir: "")) ?? BoardConfig()
        let projectConfig = (try? await loadProjectConfig(source: source, dir: folder)) ?? ProjectConfig()
        let effective = resolveEffectiveConfig(rootConfig, projectConfig)
        return try await withThrowingTaskGroup(of: Int.self) { group -> Int in
            for lane in effective.lanes {
                group.addTask {
                    let entries = (try? await source.list(join(folder, lane.folder))) ?? []
                    return entries.filter {
                        $0.kind == .file && $0.name.hasSuffix(".md") && $0.name != "README.md" && !$0.name.hasPrefix("00-")
                    }.count
                }
            }
            var total = 0
            for try await count in group { total += count }
            return total
        }
    }

    /// Load (and sort) the cards for a single lane on demand — used to lazily load a
    /// backlog lane that `loadProjectBoard(loadBacklog: false)` skipped.
    public static func loadLaneCards(
        source: BoardFileSource, project: BoardProject, lane: Lane, rootConfig: BoardConfig
    ) async throws -> [Card] {
        let effective = resolveEffectiveConfig(rootConfig, project.config)
        let cards = try await loadCards(
            source: source, dir: join(project.folder, lane.folder), fieldSource: effective.fieldSource)
        return BoardStore.sortedCards(cards, config: effective)
    }

    // MARK: - Helpers

    /// Load every card file in a directory (skipping README/index files), matching
    /// `BoardStore.loadCards`'s filtering and pre-sort by file name.
    private static func loadCards(
        source: BoardFileSource,
        dir: String,
        fieldSource: FieldSource?
    ) async throws -> [Card] {
        let entries = (try? await source.list(dir)) ?? []
        let names = entries
            .filter { $0.kind == .file }
            .filter { $0.name.hasSuffix(".md") && $0.name != "README.md" && !$0.name.hasPrefix("00-") }
            .sorted { $0.name < $1.name }

        // Read every card file concurrently, then restore file-name order.
        return try await withThrowingTaskGroup(of: (Int, Card).self) { group -> [Card] in
            for (index, entry) in names.enumerated() {
                group.addTask {
                    let text = try await source.readText(entry.path)
                    return (index, BoardStore.parseCard(text: text, fileName: entry.name, fieldSource: fieldSource))
                }
            }
            var results: [(Int, Card)] = []
            for try await pair in group { results.append(pair) }
            return results.sorted { $0.0 < $1.0 }.map(\.1)
        }
    }

    private static func loadBoardConfig(source: BoardFileSource, dir: String) async throws -> BoardConfig {
        guard let text = try? await source.readText(join(dir, "README.md")) else { return BoardConfig() }
        let (frontmatter, _) = BoardMarkdown.splitFrontmatter(text)
        guard let frontmatter else { return BoardConfig() }
        return try BoardStore.parseBoardConfig(yaml: frontmatter)
    }

    private static func loadProjectConfig(source: BoardFileSource, dir: String) async throws -> ProjectConfig {
        guard let text = try? await source.readText(join(dir, "README.md")) else { return ProjectConfig() }
        let (frontmatter, _) = BoardMarkdown.splitFrontmatter(text)
        guard let frontmatter else { return ProjectConfig() }
        return try BoardStore.parseProjectConfig(yaml: frontmatter)
    }

    /// Join two repo-relative path components with a single `/`, tolerating an empty
    /// base (the repo root).
    private static func join(_ base: String, _ component: String) -> String {
        base.isEmpty ? component : "\(base)/\(component)"
    }
}
