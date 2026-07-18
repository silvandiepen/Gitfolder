import AppKit
import Foundation
import GitKit
import Observation

enum BoardEditError: LocalizedError {
    case noFile
    var errorDescription: String? {
        switch self {
        case .noFile: return "This card has no file on disk to save to."
        }
    }
}

/// Loads a board (a folder of markdown cards) and exposes it as columns for the UI.
/// Read-only for now — editing/sync come with later tickets.
@MainActor
@Observable
final class BoardViewModel {
    var boardName = "GitKanban"
    var columns: [Column] = []
    var uncategorised: [Card] = []
    var errorMessage: String?

    /// The opened board folder, if any (nil for the sample board). Cards are flat
    /// `.md` files inside it, so a card's file is `folderURL/<fileName>`.
    private(set) var folderURL: URL?
    /// The card shown in the detail/preview sheet, if any.
    var selectedCard: Card?

    /// The default five-lane board (matches the shared Tasks contract).
    static let defaultConfig: EffectiveConfig = resolveEffectiveConfig(
        BoardConfig(
            lanes: [
                Lane(id: "todo", name: "To do", folder: "1. To do", status: "todo"),
                Lane(id: "in-progress", name: "In Progress", folder: "2. In Progress", status: "in-progress"),
                Lane(id: "in-review", name: "In Review", folder: "3. In Review", status: "in-review"),
                Lane(id: "testing", name: "Testing", folder: "4. Testing", status: "testing"),
                Lane(id: "done", name: "Done", folder: "5. Done", status: "done", terminal: true),
            ],
            priorities: [Priority(id: "P0"), Priority(id: "P1"), Priority(id: "P2"), Priority(id: "P3")]
        )
    )

    func loadSampleIfEmpty() {
        guard columns.isEmpty else { return }
        let cards = [
            Card(fields: CardFields(id: "SAMPLE-1", title: "Point GitKanban at a git repo", project: "sample", status: "todo", priority: "P1", assignee: "sil"), body: ""),
            Card(fields: CardFields(id: "SAMPLE-2", title: "Move a card — it's one commit", project: "sample", status: "in-progress", priority: "P0", assignee: "herma"), body: ""),
            Card(fields: CardFields(id: "SAMPLE-3", title: "Full history, no server", project: "sample", status: "done", priority: "P2"), body: ""),
        ]
        apply(cards: cards, config: Self.defaultConfig, name: "Sample board")
    }

    func openFolder() {
        let panel = NSOpenPanel()
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.allowsMultipleSelection = false
        panel.prompt = "Open Board"
        guard panel.runModal() == .OK, let url = panel.url else { return }
        load(folder: url)
    }

    func load(folder: URL) {
        do {
            let config = detectConfig(in: folder)
            let cards = try BoardStore.loadCards(in: folder, fieldSource: config.fieldSource)
            folderURL = folder
            apply(cards: cards, config: config, name: folder.lastPathComponent)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    // MARK: - Card files (read / edit)

    /// The on-disk file backing a card, or nil for sample cards with no folder.
    func fileURL(for card: Card) -> URL? {
        guard let folderURL, let fileName = card.fileName else { return nil }
        return folderURL.appendingPathComponent(fileName)
    }

    /// A card is editable only when it maps to a real file we opened.
    func canEdit(_ card: Card) -> Bool { fileURL(for: card) != nil }

    /// The raw markdown file (frontmatter + body) as plain text, for the editor.
    func rawText(for card: Card) -> String? {
        guard let url = fileURL(for: card) else { return nil }
        return try? String(contentsOf: url, encoding: .utf8)
    }

    /// Write the edited text straight back to the card's file, then reload the
    /// board. Plain text in, plain text out — git commit/sync is a later ticket.
    func save(card: Card, text: String) throws {
        guard let url = fileURL(for: card) else {
            throw BoardEditError.noFile
        }
        try text.write(to: url, atomically: true, encoding: .utf8)
        if let folderURL { load(folder: folderURL) }
    }

    private func apply(cards: [Card], config: EffectiveConfig, name: String) {
        let grouped = BoardStore.columns(cards: cards, config: config)
        columns = grouped.columns
        uncategorised = grouped.uncategorised
        boardName = name
        errorMessage = nil
    }

    /// Detect the legacy audit format (fields in a `## Status` section, ids in the
    /// filename) so those boards open too; otherwise use frontmatter.
    private func detectConfig(in folder: URL) -> EffectiveConfig {
        let names = (try? FileManager.default.contentsOfDirectory(atPath: folder.path)) ?? []
        let looksLikeAudit = names.contains { BoardMarkdown.parseAuditFilename($0) != nil }
        guard looksLikeAudit else { return Self.defaultConfig }
        return EffectiveConfig(
            lanes: Self.defaultConfig.lanes,
            priorities: Self.defaultConfig.priorities,
            fieldSource: .bodySection(section: "Status", map: ["status": "State", "assignee": "Assignee"])
        )
    }
}
