import XCTest
@testable import GitKit

final class ProjectReadmeTests: XCTestCase {
    private let lanes = [
        Lane(id: "todo", name: "To do", folder: "1. To do", status: "todo"),
        Lane(id: "in-progress", name: "In Progress", folder: "2. In Progress", status: "in-progress"),
        Lane(id: "in-review", name: "In Review", folder: "3. In Review", status: "in-review"),
        Lane(id: "testing", name: "Testing", folder: "4. Testing", status: "testing"),
        Lane(id: "done", name: "Done", folder: "5. Done", status: "done", terminal: true),
    ]
    private let priorities = [
        Priority(id: "P0"),
        Priority(id: "P1"),
        Priority(id: "P2"),
        Priority(id: "P3"),
    ]
    private let users = [User(id: "sil", name: "Sil van Diepen")]

    func testProjectReadmeRoundTrips() throws {
        let readme = BoardStore.renderProjectReadme(
            name: "My Project",
            description: "A test project.",
            lanes: lanes,
            priorities: priorities,
            users: users
        )

        // Body renders name and description.
        XCTAssertTrue(readme.contains("# My Project"))
        XCTAssertTrue(readme.contains("A test project."))
        // Folders with leading digits / dots are quoted.
        XCTAssertTrue(readme.contains("folder: \"1. To do\""))

        let (frontmatter, _) = BoardMarkdown.splitFrontmatter(readme)
        let config = try BoardStore.parseProjectConfig(yaml: try XCTUnwrap(frontmatter))

        XCTAssertEqual(config.project, "My Project")

        let parsedLanes = try XCTUnwrap(config.lanes)
        XCTAssertEqual(parsedLanes.map(\.folder), ["1. To do", "2. In Progress", "3. In Review", "4. Testing", "5. Done"])
        XCTAssertEqual(parsedLanes.map(\.status), ["todo", "in-progress", "in-review", "testing", "done"])
        XCTAssertEqual(parsedLanes.last?.terminal, true)
        XCTAssertNil(parsedLanes.first?.terminal)

        let parsedPriorities = try XCTUnwrap(config.priorities)
        XCTAssertEqual(parsedPriorities.map(\.id), ["P0", "P1", "P2", "P3"])

        let parsedUsers = try XCTUnwrap(config.users)
        XCTAssertEqual(parsedUsers.map(\.id), ["sil"])
        XCTAssertEqual(parsedUsers.first?.name, "Sil van Diepen")
    }
}
