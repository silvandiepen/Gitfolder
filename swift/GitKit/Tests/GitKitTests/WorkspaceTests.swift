import XCTest
@testable import GitKit

final class WorkspaceTests: XCTestCase {
    private var root: URL!

    override func setUpWithError() throws {
        root = FileManager.default.temporaryDirectory
            .appendingPathComponent("gitkit-workspace-\(UUID().uuidString)", isDirectory: true)
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
        // Root config: lanes + shared vocabularies.
        try write("""
        ---
        lanes:
          - id: todo
            name: To do
            folder: "1. To do"
            status: todo
          - id: in-progress
            name: In Progress
            folder: "2. In Progress"
            status: in-progress
          - id: done
            name: Done
            folder: "3. Done"
            status: done
            terminal: true
        users:
          - id: sil
          - id: herma
        priorities:
          - id: P0
          - id: P1
          - id: P2
        ---

        # Tasks
        """, to: "README.md")

        // Project Alpha: project config adds an epic; overrides nothing else.
        try write("""
        ---
        config: project
        project: Alpha
        epics:
          - id: launch
            name: Launch
        ---

        # Alpha
        """, to: "Alpha/README.md")

        try write("""
        ---
        id: A-1
        title: First task
        status: todo
        assignee: sil
        priority: P1
        ---

        # First task
        """, to: "Alpha/1. To do/A-1.md")

        try write("""
        ---
        id: A-2
        title: Second task
        status: todo
        assignee: herma
        priority: P0
        ---

        # Second task
        """, to: "Alpha/1. To do/A-2.md")

        try write("""
        ---
        id: A-3
        title: In flight
        status: in-progress
        assignee: sil
        priority: P0
        ---

        # In flight
        """, to: "Alpha/2. In Progress/A-3.md")

        // A README + an ignorable 00- file in a lane folder should be skipped.
        try write("# ignore me", to: "Alpha/1. To do/README.md")
        try write("# overview", to: "Alpha/1. To do/00-OVERVIEW.md")

        // A non-project folder (no README) must not be picked up as a project.
        try FileManager.default.createDirectory(
            at: root.appendingPathComponent(".git"), withIntermediateDirectories: true
        )
    }

    func testLoadWorkspaceFindsProjectAlpha() throws {
        try makeTree()
        let workspace = try BoardStore.loadWorkspace(at: root)

        XCTAssertEqual(workspace.rootConfig.lanes.map(\.id), ["todo", "in-progress", "done"])
        XCTAssertEqual(workspace.projects.map(\.name), ["Alpha"])

        let alpha = try XCTUnwrap(workspace.projects.first)
        XCTAssertEqual(alpha.id, "Alpha")
        XCTAssertEqual(alpha.folder, "Alpha")
        XCTAssertEqual(alpha.config.project, "Alpha")
    }

    func testLoadProjectBoardPlacesCardsInColumns() throws {
        try makeTree()
        let workspace = try BoardStore.loadWorkspace(at: root)
        let alpha = try XCTUnwrap(workspace.projects.first)

        let board = try BoardStore.loadProjectBoard(
            root: root, project: alpha, rootConfig: workspace.rootConfig
        )

        // Effective config merges root vocab with the project's epic.
        XCTAssertEqual(board.config.project, "Alpha")
        XCTAssertEqual(board.config.lanes.map(\.id), ["todo", "in-progress", "done"])
        XCTAssertEqual(board.config.users.map(\.id), ["sil", "herma"])
        XCTAssertEqual(board.config.epics.map(\.id), ["launch"])

        XCTAssertEqual(board.columns.map(\.lane.id), ["todo", "in-progress", "done"])
        // Within "To do", P0 sorts before P1.
        XCTAssertEqual(board.columns[0].cards.map { $0.fields.id }, ["A-2", "A-1"])
        XCTAssertEqual(board.columns[1].cards.map { $0.fields.id }, ["A-3"])
        XCTAssertTrue(board.columns[2].cards.isEmpty)
        XCTAssertTrue(board.uncategorised.isEmpty)
    }
}
