import GitKit
import XCTest
@testable import GitKanbanKit

/// Exercises the board write flows end-to-end against the in-memory demo source, so
/// create / edit / move / delete / reorder are verified in the shared module.
@MainActor
final class AppModelWriteTests: XCTestCase {

    private func loaded() async -> AppModel {
        let model = AppModel()
        await model.loadDemo()
        return model
    }

    private func lane(_ model: AppModel, _ id: String) -> Lane {
        model.board!.columns.first { $0.lane.id == id }!.lane
    }

    private func cards(_ model: AppModel, _ id: String) -> [Card] {
        model.board!.columns.first { $0.lane.id == id }!.cards
    }

    func testDemoLoads() async {
        let model = await loaded()
        XCTAssertEqual(model.selectedProject?.name, "Demo Project")
        XCTAssertEqual(model.board?.columns.map(\.lane.id), ["backlog", "to-do", "in-progress", "done"])
        XCTAssertEqual(cards(model, "to-do").count, 4)
    }

    /// Backlog lanes load lazily (skipped on first board load).
    func testBacklogLazyLoad() async {
        let model = await loaded()
        XCTAssertTrue(cards(model, "backlog").isEmpty)
        await model.loadBacklogLane(lane(model, "backlog"))
        XCTAssertEqual(cards(model, "backlog").count, 3)
    }

    func testCreateTask() async {
        let model = await loaded()
        let before = cards(model, "to-do").count
        await model.createTask(title: "Fresh task", lane: lane(model, "to-do"),
                               priority: "P1", type: "feature", assignee: "sil", body: "hello")
        XCTAssertEqual(cards(model, "to-do").count, before + 1)
        let created = cards(model, "to-do").first { $0.fields.title == "Fresh task" }
        XCTAssertNotNil(created)
        XCTAssertEqual(created?.fields.priority, "P1")
        XCTAssertEqual(created?.fields.assignee, "sil")
        XCTAssertEqual(created?.fields.status, "to-do")
    }

    func testMoveCard() async {
        let model = await loaded()
        let card = cards(model, "to-do").first!
        await model.moveCard(card, to: lane(model, "in-progress"))
        XCTAssertFalse(cards(model, "to-do").contains { $0.fields.id == card.fields.id })
        let moved = cards(model, "in-progress").first { $0.fields.id == card.fields.id }
        XCTAssertNotNil(moved)
        XCTAssertEqual(moved?.fields.status, "in-progress")
    }

    func testUpdateCard() async {
        let model = await loaded()
        let card = cards(model, "to-do").first!
        await model.updateCard(card, title: "Renamed", laneID: "to-do",
                               priority: "P0", type: "bug", assignee: "alex", body: "updated body")
        let updated = cards(model, "to-do").first { $0.fields.id == card.fields.id }
        XCTAssertEqual(updated?.fields.title, "Renamed")
        XCTAssertEqual(updated?.fields.priority, "P0")
        XCTAssertEqual(updated?.fields.type, "bug")
        XCTAssertEqual(updated?.fields.assignee, "alex")
    }

    func testUpdateCardMovesLane() async {
        let model = await loaded()
        let card = cards(model, "to-do").first!
        await model.updateCard(card, title: card.fields.title, laneID: "done",
                               priority: card.fields.priority ?? "", type: card.fields.type ?? "",
                               assignee: card.fields.assignee ?? "", body: card.body)
        XCTAssertFalse(cards(model, "to-do").contains { $0.fields.id == card.fields.id })
        XCTAssertTrue(cards(model, "done").contains { $0.fields.id == card.fields.id })
    }

    func testDeleteCard() async {
        let model = await loaded()
        let card = cards(model, "to-do").first!
        let before = cards(model, "to-do").count
        await model.deleteCard(card)
        XCTAssertEqual(cards(model, "to-do").count, before - 1)
    }

    func testReorder() async {
        let model = await loaded()
        let todo = lane(model, "to-do")
        let ids = cards(model, "to-do").map { $0.fields.id }
        let reversed = Array(ids.reversed())
        await model.reorderCards(in: todo, orderedIDs: reversed)
        XCTAssertEqual(cards(model, "to-do").map { $0.fields.id }, reversed)
    }

    func testFilters() async {
        let model = await loaded()
        model.filterAssignee = "sil"
        let silCards = model.allCards.filter(model.matchesFilters)
        XCTAssertTrue(silCards.allSatisfy { $0.fields.assignee == "sil" })
        XCTAssertFalse(silCards.isEmpty)
        model.clearFilters()
        XCTAssertFalse(model.hasActiveFilters)
    }

    func testDuplicateCard() async {
        let model = await loaded()
        let before = cards(model, "to-do").count
        await model.duplicateCard(cards(model, "to-do").first!)
        XCTAssertEqual(cards(model, "to-do").count, before + 1)
    }
}
