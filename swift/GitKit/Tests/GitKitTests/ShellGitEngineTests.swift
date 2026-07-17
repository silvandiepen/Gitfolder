import XCTest
@testable import GitKit

/// Drives `ShellGitEngine` against a throwaway local bare "remote" and two clones,
/// so no network or credentials are needed. Runs wherever `git` is on PATH.
final class ShellGitEngineTests: XCTestCase {
    private let runner = GitProcessRunner()
    private let engine = ShellGitEngine()
    private var tmp: URL!

    override func setUpWithError() throws {
        tmp = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("gitkit-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: tmp, withIntermediateDirectories: true)
    }

    override func tearDownWithError() throws {
        try? FileManager.default.removeItem(at: tmp)
    }

    private func configureIdentity(_ repo: URL) throws {
        try runner.run(["config", "user.email", "test@example.com"], in: repo)
        try runner.run(["config", "user.name", "GitKit Test"], in: repo)
    }

    private func write(_ text: String, to repo: URL, _ name: String) throws {
        try Data(text.utf8).write(to: repo.appendingPathComponent(name))
    }

    func testCloneCommitPushPullAndHistory() async throws {
        let remote = tmp.appendingPathComponent("remote.git")
        try runner.run(["init", "--bare", remote.path], in: tmp)

        // Clone A, commit a card, push.
        let a = tmp.appendingPathComponent("a")
        try await engine.clone(remote, to: a, auth: .sshAgent)
        try configureIdentity(a)
        try write("hello\n", to: a, "card.md")
        try await engine.commit(at: a, message: "add card", paths: [])
        try await engine.push(at: a, auth: .sshAgent)

        // Clone B sees the pushed card, a clean tree, and one commit of history.
        let b = tmp.appendingPathComponent("b")
        try await engine.clone(remote, to: b, auth: .sshAgent)
        XCTAssertTrue(FileManager.default.fileExists(atPath: b.appendingPathComponent("card.md").path))

        let status = try await engine.status(at: b)
        XCTAssertTrue(status.clean)
        XCTAssertEqual(status.changedPaths, [])

        let history = try await engine.fileHistory(at: b, file: "card.md", limit: 10)
        XCTAssertEqual(history.count, 1)
        XCTAssertEqual(history.first?.message, "add card")
        XCTAssertEqual(history.first?.author, "GitKit Test")

        // A moves the card (one-line change), pushes; B pulls it cleanly.
        try configureIdentity(b)
        try write("hello world\n", to: a, "card.md")
        try await engine.commit(at: a, message: "move card to done", paths: ["card.md"])
        try await engine.push(at: a, auth: .sshAgent)

        let pull = try await engine.pullRebase(at: b, auth: .sshAgent)
        XCTAssertTrue(pull.updated)
        XCTAssertTrue(pull.conflicts.isEmpty)

        let history2 = try await engine.fileHistory(at: b, file: "card.md", limit: 10)
        XCTAssertEqual(history2.count, 2)
    }

    func testCommitWithNothingStagedThrows() async throws {
        let repo = tmp.appendingPathComponent("solo")
        try runner.run(["init", repo.path], in: tmp)
        try configureIdentity(repo)
        do {
            try await engine.commit(at: repo, message: "empty", paths: [])
            XCTFail("expected nothingToCommit")
        } catch GitEngineError.nothingToCommit {
            // expected
        }
    }

    func testStatusReportsUncommittedChanges() async throws {
        let remote = tmp.appendingPathComponent("remote2.git")
        try runner.run(["init", "--bare", remote.path], in: tmp)
        let a = tmp.appendingPathComponent("a2")
        try await engine.clone(remote, to: a, auth: .sshAgent)
        try configureIdentity(a)
        try write("one\n", to: a, "card.md")
        try await engine.commit(at: a, message: "seed", paths: [])

        // Dirty the working tree without committing.
        try write("changed\n", to: a, "card.md")
        let status = try await engine.status(at: a)
        XCTAssertFalse(status.clean)
        XCTAssertTrue(status.changedPaths.contains("card.md"))
    }
}
