import Foundation
import GitKit

/// A board file source that also supports writes — the abstraction `AppModel` drives,
/// so the same board/edit flows run over the real provider API (`GitPontFileSource`)
/// or the offline in-memory demo (`InMemoryBoardSource`).
protocol BoardWritable: BoardFileSource {
    func write(path: String, text: String, message: String) async throws
    func delete(path: String, message: String) async throws
}

extension GitPontFileSource: BoardWritable {}

/// A fully in-memory, writable board — used for the offline demo so the app can be
/// explored (and every edit flow tested) without connecting to a provider.
actor InMemoryBoardSource: BoardWritable {
    private var files: [String: String]

    init(files: [String: String]) { self.files = files }

    func list(_ directory: String) -> [BoardFileEntry] {
        let prefix = directory.isEmpty ? "" : directory + "/"
        var fileNames = Set<String>()
        var dirNames = Set<String>()
        for key in files.keys where key.hasPrefix(prefix) {
            let rest = String(key.dropFirst(prefix.count))
            guard !rest.isEmpty else { continue }
            if let slash = rest.firstIndex(of: "/") {
                dirNames.insert(String(rest[..<slash]))
            } else {
                fileNames.insert(rest)
            }
        }
        return fileNames.map { BoardFileEntry(name: $0, path: prefix + $0, kind: .file) }
            + dirNames.map { BoardFileEntry(name: $0, path: prefix + $0, kind: .directory) }
    }

    func readText(_ path: String) throws -> String {
        guard let text = files[path] else {
            throw NSError(domain: "InMemoryBoardSource", code: 404,
                          userInfo: [NSLocalizedDescriptionKey: "No such file: \(path)"])
        }
        return text
    }

    func write(path: String, text: String, message: String) { files[path] = text }
    func delete(path: String, message: String) { files[path] = nil }

    /// A seeded demo workspace: one project, a backlog + pipeline lanes, sample cards.
    static func demo() -> InMemoryBoardSource {
        var files: [String: String] = [:]
        files["Test Project/README.md"] = """
        ---
        config: project
        project: "Demo Project"
        lanes:
          - id: backlog
            name: Backlog
            folder: "0. Backlog"
            status: backlog
            backlog: true
          - id: to-do
            name: "To do"
            folder: "1. To do"
            status: to-do
          - id: in-progress
            name: "In Progress"
            folder: "2. In Progress"
            status: in-progress
          - id: done
            name: Done
            folder: "3. Done"
            status: done
            terminal: true
        priorities:
          - id: P0
          - id: P1
          - id: P2
          - id: P3
        users:
          - id: sil
            name: "Sil van Diepen"
          - id: alex
            name: "Alex Rivera"
        ---

        # Demo Project
        """

        func card(_ folder: String, _ id: String, _ title: String, _ status: String,
                  priority: String?, type: String?, assignee: String?, order: Int) {
            files["Test Project/\(folder)/\(id).md"] = CardText.make(
                id: id, title: title, project: "Demo Project", status: status,
                priority: priority, type: type, assignee: assignee, order: String(order),
                body: "## \(title)\n\nA sample task for the offline demo board."
            )
        }

        card("0. Backlog", "DEMO-1", "Offline sync spike", "backlog", priority: "P1", type: "feature", assignee: "alex", order: 1)
        card("0. Backlog", "DEMO-2", "Dark mode", "backlog", priority: "P2", type: "enhancement", assignee: nil, order: 2)
        card("0. Backlog", "DEMO-3", "Keyboard shortcuts", "backlog", priority: "P3", type: "enhancement", assignee: "sil", order: 3)
        card("1. To do", "DEMO-4", "Design onboarding", "to-do", priority: "P1", type: "feature", assignee: "sil", order: 1)
        card("1. To do", "DEMO-5", "Repo picker polish", "to-do", priority: "P2", type: "enhancement", assignee: "alex", order: 2)
        card("2. In Progress", "DEMO-6", "Board rendering", "in-progress", priority: "P0", type: "feature", assignee: "sil", order: 1)
        card("2. In Progress", "DEMO-7", "Card editor", "in-progress", priority: "P1", type: "feature", assignee: "alex", order: 2)
        card("3. Done", "DEMO-8", "Connect via token", "done", priority: "P0", type: "feature", assignee: "sil", order: 1)

        return InMemoryBoardSource(files: files)
    }
}
