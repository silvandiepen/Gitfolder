import Foundation
import XCTest
@testable import GitFolder

final class ConfigStoreTests: XCTestCase {
    func testDefaultConfigKeepsPurchaseMetadataOutOfAppState() {
        let config = GitFolderConfig.empty

        XCTAssertEqual(config.schemaVersion, 1)
        XCTAssertTrue(config.folders.isEmpty)
        XCTAssertEqual(config.app.defaultSyncIntervalMinutes, 15)
    }

    func testSyncedFolderCreateKeepsConfiguredInterval() {
        let folder = SyncedFolder.create(
            name: "Documents",
            localPath: "/tmp/Documents",
            bookmarkData: nil,
            repoUrl: "git@github.com:silvandiepen/documents.git",
            branch: "main",
            syncIntervalMinutes: 30
        )

        XCTAssertEqual(folder.syncIntervalMinutes, 30)
        XCTAssertEqual(folder.branch, "main")
        XCTAssertEqual(folder.lastStatus, .idle)
        XCTAssertTrue(folder.enabled)
    }

    func testSnapshotCommitMessageIsStableAndIdentifiable() {
        let date = Date(timeIntervalSince1970: 1_700_000_000)

        let message = SnapshotCommitMessage.make(date: date)

        XCTAssertTrue(message.hasPrefix("GitFolder snapshot "))
        XCTAssertTrue(message.contains("T"))
        XCTAssertTrue(message.contains("Z"))
    }

    func testSyncCreatesCommitAndPushesToLocalRemote() async throws {
        let root = try temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: root) }

        let source = root.appending(path: "source", directoryHint: .isDirectory)
        let remote = root.appending(path: "remote.git", directoryHint: .isDirectory)
        try FileManager.default.createDirectory(at: source, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: remote, withIntermediateDirectories: true)

        _ = try runGit(["init", "--bare"], in: remote)
        _ = try runGit(["init"], in: source)
        try "hello".write(to: source.appending(path: "note.txt"), atomically: true, encoding: .utf8)

        let folder = SyncedFolder.create(
            name: "source",
            localPath: source.path,
            bookmarkData: nil,
            repoUrl: remote.path,
            branch: "main",
            syncIntervalMinutes: 15
        )

        let engine = GitSyncEngine(now: { Date(timeIntervalSince1970: 1_700_000_000) })
        let options = GitSyncOptions(
            gitAuthorName: "GitFolder Test",
            gitAuthorEmail: "gitfolder@example.com",
            sshPrivateKeyPath: nil,
            sshPrivateKeyBookmarkData: nil
        )
        let outcome = try await engine.sync(folder, options: options)

        XCTAssertTrue(outcome.changed)
        XCTAssertTrue(outcome.pushed)
        XCTAssertEqual(outcome.folder.lastStatus, .synced)
        XCTAssertNotNil(outcome.folder.lastSuccessfulSyncAt)

        let remoteHead = try runGit(["--git-dir", remote.path, "rev-parse", "main"], in: root)
        XCTAssertFalse(remoteHead.standardOutput.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
    }

    func testSyncRejectsFolderWithoutRepositoryURL() async throws {
        let folder = SyncedFolder.create(
            name: "source",
            localPath: "/tmp/source",
            bookmarkData: nil,
            repoUrl: "",
            branch: "main"
        )
        let engine = GitSyncEngine()

        do {
            _ = try await engine.sync(folder)
            XCTFail("Expected missing repository URL error")
        } catch let error as GitSyncError {
            XCTAssertEqual(error, .missingRepositoryURL)
        }
    }

    private func temporaryDirectory() throws -> URL {
        let url = FileManager.default.temporaryDirectory
            .appending(path: "GitFolderTests-\(UUID().uuidString)", directoryHint: .isDirectory)
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }

    @discardableResult
    private func runGit(_ arguments: [String], in workingDirectory: URL) throws -> GitCommandResult {
        let result = try GitRunner().run(arguments, in: workingDirectory, timeoutSeconds: 60)
        XCTAssertEqual(result.exitCode, 0, result.standardError)
        return result
    }
}
