import XCTest
@testable import GitKit

/// A `BoardFileSource` backed by an on-disk directory, used to prove the async
/// remote loader produces byte-identical boards to the disk `BoardStore`.
private struct DiskFileSource: BoardFileSource {
    let root: URL

    func list(_ directory: String) async throws -> [BoardFileEntry] {
        let dir = directory.isEmpty ? root : root.appendingPathComponent(directory)
        let urls = try FileManager.default.contentsOfDirectory(
            at: dir, includingPropertiesForKeys: [.isDirectoryKey], options: []
        )
        return urls.map { url in
            let isDir = (try? url.resourceValues(forKeys: [.isDirectoryKey]))?.isDirectory ?? false
            let name = url.lastPathComponent
            let path = directory.isEmpty ? name : "\(directory)/\(name)"
            return BoardFileEntry(name: name, path: path, kind: isDir ? .directory : .file)
        }
    }

    func readText(_ path: String) async throws -> String {
        try String(contentsOf: root.appendingPathComponent(path), encoding: .utf8)
    }
}

final class RemoteBoardStoreTests: XCTestCase {
    private var root: URL!

    override func setUpWithError() throws {
        root = FileManager.default.temporaryDirectory
            .appendingPathComponent("gitkit-remote-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
    }

    override func tearDownWithError() throws {
        try? FileManager.default.removeItem(at: root)
    }

    private func write(_ text: String, to relativePath: String) throws {
        let url = root.appendingPathComponent(relativePath)
        try FileManager.default.createDirectory(
            at: url.deletingLastPathComponent(), withIntermediateDirectories: true
        )
        try text.write(to: url, atomically: true, encoding: .utf8)
    }

    private func makeTree() throws {
        try write("""
        ---
        lanes:
          - id: backlog
            name: Backlog
            folder: "0. Backlog"
            status: backlog
            backlog: true
          - id: todo
            name: To do
            folder: "1. To do"
            status: todo
          - id: done
            name: Done
            folder: "2. Done"
            status: done
            terminal: true
        priorities:
          - id: P0
          - id: P1
        ---

        # Tasks
        """, to: "README.md")

        try write("""
        ---
        config: project
        project: Alpha
        ---

        # Alpha
        """, to: "Alpha/README.md")

        try write("---\nid: A-1\ntitle: One\nstatus: todo\npriority: P1\norder: \"2\"\n---\n\n# One", to: "Alpha/1. To do/A-1.md")
        try write("---\nid: A-2\ntitle: Two\nstatus: todo\npriority: P1\norder: \"10\"\n---\n\n# Two", to: "Alpha/1. To do/A-2.md")
        try write("---\nid: B-1\ntitle: Backlog one\nstatus: backlog\n---\n\n# Backlog one", to: "Alpha/0. Backlog/B-1.md")
        // Skipped files.
        try write("# ignore", to: "Alpha/1. To do/README.md")
        try write("# ignore", to: "Alpha/1. To do/00-OVERVIEW.md")
    }

    func testRemoteWorkspaceMatchesDisk() async throws {
        try makeTree()
        let disk = try BoardStore.loadWorkspace(at: root)
        let remote = try await RemoteBoardStore.loadWorkspace(source: DiskFileSource(root: root))

        XCTAssertEqual(remote.rootConfig.lanes.map(\.id), disk.rootConfig.lanes.map(\.id))
        XCTAssertEqual(remote.projects.map(\.name), disk.projects.map(\.name))
        // The backlog flag survives the remote round-trip.
        XCTAssertTrue(remote.rootConfig.lanes.first { $0.id == "backlog" }?.isBacklog == true)
    }

    func testRemoteProjectBoardMatchesDisk() async throws {
        try makeTree()
        let source = DiskFileSource(root: root)
        let workspace = try await RemoteBoardStore.loadWorkspace(source: source)
        let alpha = try XCTUnwrap(workspace.projects.first)

        let remote = try await RemoteBoardStore.loadProjectBoard(
            source: source, project: alpha, rootConfig: workspace.rootConfig
        )
        let disk = try BoardStore.loadProjectBoard(
            root: root,
            project: try XCTUnwrap(try BoardStore.loadWorkspace(at: root).projects.first),
            rootConfig: workspace.rootConfig
        )

        XCTAssertEqual(remote.columns.map(\.lane.id), disk.columns.map(\.lane.id))
        for (r, d) in zip(remote.columns, disk.columns) {
            XCTAssertEqual(r.cards.map { $0.fields.id }, d.cards.map { $0.fields.id }, "lane \(r.lane.id)")
        }
        // Numeric order: order "2" sorts before order "10".
        let todo = try XCTUnwrap(remote.columns.first { $0.lane.id == "todo" })
        XCTAssertEqual(todo.cards.map { $0.fields.id }, ["A-1", "A-2"])
        // Backlog cards load into the backlog lane.
        let backlog = try XCTUnwrap(remote.columns.first { $0.lane.id == "backlog" })
        XCTAssertEqual(backlog.cards.map { $0.fields.id }, ["B-1"])
    }
}
