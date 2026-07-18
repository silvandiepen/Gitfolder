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

    /// Load the workspace at the repo root: the root config plus every project folder
    /// (an immediate subdirectory containing a `README.md`), sorted by display name.
    public static func loadWorkspace(source: BoardFileSource) async throws -> Workspace {
        let rootConfig = (try? await loadBoardConfig(source: source, dir: "")) ?? BoardConfig()
        let entries = (try? await source.list("")) ?? []

        var projects: [BoardProject] = []
        for entry in entries where entry.kind == .directory {
            let folder = entry.name
            guard !folder.hasPrefix("."), folder != ".git" else { continue }
            let children = (try? await source.list(entry.path)) ?? []
            guard children.contains(where: { $0.kind == .file && $0.name == "README.md" }) else { continue }

            let config = (try? await loadProjectConfig(source: source, dir: entry.path)) ?? ProjectConfig()
            let name = config.project?.isEmpty == false ? config.project! : folder
            projects.append(BoardProject(id: folder, name: name, folder: folder, config: config))
        }

        projects.sort { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
        return Workspace(rootConfig: rootConfig, projects: projects)
    }

    /// Resolve and load one project's board. Cards are read from each lane's folder
    /// (the lane is known from the folder, not the card `status`) and sorted the same
    /// way the disk loader sorts them. Non-lane subfolders become `uncategorised`.
    public static func loadProjectBoard(
        source: BoardFileSource,
        project: BoardProject,
        rootConfig: BoardConfig
    ) async throws -> LoadedBoard {
        let effective = resolveEffectiveConfig(rootConfig, project.config)

        var columns: [Column] = []
        var laneFolders = Set<String>()
        for lane in effective.lanes {
            laneFolders.insert(lane.folder)
            let cards = try await loadCards(
                source: source,
                dir: join(project.folder, lane.folder),
                fieldSource: effective.fieldSource
            )
            columns.append(Column(lane: lane, cards: BoardStore.sortedCards(cards, config: effective)))
        }

        var uncategorised: [Card] = []
        let subEntries = (try? await source.list(project.folder)) ?? []
        for entry in subEntries where entry.kind == .directory {
            guard !entry.name.hasPrefix("."), !laneFolders.contains(entry.name) else { continue }
            uncategorised += try await loadCards(source: source, dir: entry.path, fieldSource: effective.fieldSource)
        }

        return LoadedBoard(config: effective, columns: columns, uncategorised: uncategorised)
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

        var cards: [Card] = []
        for entry in names {
            let text = try await source.readText(entry.path)
            cards.append(BoardStore.parseCard(text: text, fileName: entry.name, fieldSource: fieldSource))
        }
        return cards
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
