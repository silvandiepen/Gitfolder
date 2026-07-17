import XCTest
@testable import GitKit

final class BoardTests: XCTestCase {
    private let root = BoardConfig(
        lanes: [
            Lane(id: "todo", name: "To do", folder: "1. To do", status: "todo"),
            Lane(id: "in-progress", name: "In Progress", folder: "2. In Progress", status: "in-progress"),
            Lane(id: "done", name: "Done", folder: "5. Done", status: "done", terminal: true),
        ],
        users: [User(id: "sil"), User(id: "herma")],
        epics: [],
        priorities: [Priority(id: "P0"), Priority(id: "P1"), Priority(id: "P2")],
        types: ["fix", "feature"],
        tags: []
    )

    // MARK: Inheritance

    func testInheritsRootLanesWhenProjectDefinesNone() {
        let eff = resolveEffectiveConfig(root, ProjectConfig(project: "imagekid", lanes: []))
        XCTAssertEqual(eff.lanes.map(\.id), ["todo", "in-progress", "done"])
    }

    func testReplacesLanesWhenProjectDefinesOwn() {
        let project = ProjectConfig(project: "Outreach", lanes: [
            Lane(id: "backlog", name: "Backlog", folder: "1. Backlog", status: "backlog"),
            Lane(id: "won", name: "Won", folder: "4. Won", status: "won", terminal: true),
        ])
        XCTAssertEqual(resolveEffectiveConfig(root, project).lanes.map(\.id), ["backlog", "won"])
    }

    func testMergesVocabulariesAndOverridesById() {
        let eff = resolveEffectiveConfig(root, ProjectConfig(
            users: [User(id: "sil", name: "Sil van Diepen", role: "owner"), User(id: "hermina")],
            types: ["security", "fix"]
        ))
        XCTAssertEqual(eff.users.map(\.id), ["sil", "herma", "hermina"])
        XCTAssertEqual(eff.users.first { $0.id == "sil" }?.role, "owner")
        XCTAssertEqual(eff.types, ["fix", "feature", "security"])
    }

    // MARK: YAML config parsing

    func testParsesBoardConfigFromYAML() throws {
        let yaml = """
        lanes:
          - id: todo
            name: To do
            folder: "1. To do"
            status: todo
          - id: done
            name: Done
            folder: "5. Done"
            status: done
            terminal: true
        users:
          - id: sil
            kind: human
        fieldSource:
          mode: body-section
          section: Status
          map:
            status: State
            assignee: Assignee
        """
        let config = try BoardStore.parseBoardConfig(yaml: yaml)
        XCTAssertEqual(config.lanes.map(\.id), ["todo", "done"])
        XCTAssertEqual(config.lanes.last?.terminal, true)
        XCTAssertEqual(config.users.first?.kind, "human")
        if case let .bodySection(section, map) = config.fieldSource {
            XCTAssertEqual(section, "Status")
            XCTAssertEqual(map["status"], "State")
        } else {
            XCTFail("expected body-section field source")
        }
    }

    // MARK: Card parsing

    func testParsesFrontmatterCard() {
        let text = "---\nid: X-1\ntitle: Fix it\nstatus: in-progress\npriority: P1\nassignee: sil\n---\n\n# Fix it\n"
        let card = BoardStore.parseCard(text: text, fileName: "X-1.md", fieldSource: .frontmatter)
        XCTAssertEqual(card.fields.id, "X-1")
        XCTAssertEqual(card.fields.status, "in-progress")
        XCTAssertEqual(card.fields.assignee, "sil")
    }

    func testParsesBodySectionCardAndFilename() {
        let text = """
        # ARC-0004 — Thread shadows the shared control

        **Project:** Luys

        ## Status

        - **State:** in-progress

        - **Assignee:** sil

        - **Branch / PR:** —
        """
        let source = FieldSource.bodySection(section: "Status", map: ["status": "State", "assignee": "Assignee"])
        let card = BoardStore.parseCard(text: text, fileName: "P3-ARC-0004-thread-shadows.md", fieldSource: source)
        XCTAssertEqual(card.fields.status, "in-progress")
        XCTAssertEqual(card.fields.assignee, "sil")
        XCTAssertEqual(card.fields.id, "ARC-0004")       // from filename
        XCTAssertEqual(card.fields.priority, "P3")        // from filename
        XCTAssertTrue(card.fields.title.contains("Thread shadows"))
    }

    func testParseAuditFilename() {
        XCTAssertEqual(BoardMarkdown.parseAuditFilename("P1-A11Y-0001-dynamic-type.md")?.id, "A11Y-0001")
        XCTAssertNil(BoardMarkdown.parseAuditFilename("00-OVERVIEW.md"))
    }

    // MARK: Grouping

    func testGroupsCardsIntoLanesInOrder() {
        let eff = resolveEffectiveConfig(root, ProjectConfig(project: "p"))
        func card(_ id: String, _ status: String, _ priority: String) -> Card {
            Card(fields: CardFields(id: id, title: id, project: "p", status: status, priority: priority), body: "")
        }
        let cards = [
            card("A-3", "todo", "P2"),
            card("A-1", "todo", "P0"),
            card("A-2", "in-progress", "P1"),
            card("A-9", "archived", "P0"),
        ]
        let result = BoardStore.columns(cards: cards, config: eff)
        XCTAssertEqual(result.columns.map(\.lane.id), ["todo", "in-progress", "done"])
        XCTAssertEqual(result.columns[0].cards.map { $0.fields.id }, ["A-1", "A-3"]) // priority order
        XCTAssertEqual(result.columns[1].cards.map { $0.fields.id }, ["A-2"])
        XCTAssertEqual(result.uncategorised.map { $0.fields.id }, ["A-9"])
    }
}
