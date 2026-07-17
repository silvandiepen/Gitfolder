import Foundation
import GitKit
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
        XCTAssertEqual(folder.authModeValue, .githubToken)
        XCTAssertEqual(folder.lastStatus, .idle)
        XCTAssertTrue(folder.enabled)
    }

    func testConfigEncodingDoesNotIncludeGitHubTokenValue() throws {
        let secret = "github_pat_secret_value"
        let folder = SyncedFolder.create(
            name: "Documents",
            localPath: "/tmp/Documents",
            bookmarkData: nil,
            repoUrl: "https://github.com/silvandiepen/documents.git"
        )
        let config = GitFolderConfig(schemaVersion: 1, app: .defaults, folders: [folder])

        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let data = try encoder.encode(config)
        let json = String(data: data, encoding: .utf8) ?? ""

        XCTAssertTrue(json.contains(AuthMode.githubToken.rawValue))
        XCTAssertFalse(json.contains(secret))
        XCTAssertFalse(json.localizedCaseInsensitiveContains("github_pat_"))
    }

    func testSyncedFolderCreatesRepositoryWebURLFromSSHURL() {
        let folder = SyncedFolder.create(
            name: "Documents",
            localPath: "/tmp/Documents",
            bookmarkData: nil,
            repoUrl: "git@github.com:silvandiepen/documents.git"
        )

        XCTAssertEqual(folder.repositoryWebURLString, "https://github.com/silvandiepen/documents")
    }

    func testRepositoryWebURLSupportsCommonCloneURLForms() {
        XCTAssertEqual(
            SyncedFolder.webURLString(fromRepositoryURL: "ssh://git@github.com/silvandiepen/documents.git"),
            "https://github.com/silvandiepen/documents"
        )
        XCTAssertEqual(
            SyncedFolder.webURLString(fromRepositoryURL: "https://github.com/silvandiepen/documents.git"),
            "https://github.com/silvandiepen/documents"
        )
        XCTAssertEqual(
            SyncedFolder.webURLString(fromRepositoryURL: " git@gitlab.com:group/documents.git\n"),
            "https://gitlab.com/group/documents"
        )
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
            authMode: .ssh,
            branch: "main",
            syncIntervalMinutes: 15
        )

        let engine = GitSyncEngine(now: { Date(timeIntervalSince1970: 1_700_000_000) })
        let options = GitSyncOptions(
            gitAuthorName: "GitFolder Test",
            gitAuthorEmail: "gitfolder@example.com",
            githubToken: nil,
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
            authMode: .ssh,
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

    func testSyncRejectsTokenFolderWithoutToken() async throws {
        let root = try temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: root) }
        let folder = SyncedFolder.create(
            name: "source",
            localPath: root.path,
            bookmarkData: nil,
            repoUrl: "https://github.com/silvandiepen/documents.git",
            authMode: .githubToken,
            branch: "main"
        )
        let engine = GitSyncEngine()

        do {
            _ = try await engine.sync(folder)
            XCTFail("Expected missing GitHub token error")
        } catch let error as GitSyncError {
            XCTAssertEqual(error, .missingGitHubToken)
        }
    }

    func testTokenAuthCommandConstructionDoesNotPutTokenInArguments() async throws {
        let root = try temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: root) }
        let runner = FakeGitRunner()
        let engine = GitSyncEngine(gitRunner: runner)
        let token = "github_pat_secret_value"

        try await engine.testGitHubAccess(
            repoUrl: "https://github.com/example/repo.git",
            authMode: .githubToken,
            options: GitSyncOptions(
                gitAuthorName: nil,
                gitAuthorEmail: nil,
                githubToken: token,
                sshPrivateKeyPath: nil,
                sshPrivateKeyBookmarkData: nil
            )
        )

        let calls = runner.calls
        XCTAssertEqual(calls.count, 1)
        XCTAssertFalse(calls[0].arguments.joined(separator: " ").contains(token))
        XCTAssertEqual(calls[0].environment["GITPONT_TOKEN"], token)
        XCTAssertEqual(calls[0].environment["GITPONT_USERNAME"], "x-access-token")
        XCTAssertEqual(calls[0].environment["GIT_TERMINAL_PROMPT"], "0")
    }

    func testGitRunnerLaunchFailureIncludesExecutablePath() throws {
        let missingGitPath = "/tmp/gitfolder-missing-git-\(UUID().uuidString)"
        let runner = GitRunner(gitExecutableURL: URL(fileURLWithPath: missingGitPath))

        do {
            _ = try runner.run(["--version"], in: FileManager.default.temporaryDirectory, timeoutSeconds: 1)
            XCTFail("Expected Git launch failure")
        } catch {
            let message = error.localizedDescription
            XCTAssertTrue(message.contains("Could not launch Git"), message)
            XCTAssertTrue(message.contains(missingGitPath), message)
        }
    }

    func testKeychainServiceStoresReplacesAndDeletesToken() throws {
        let service = KeychainService(service: "app.hakobs.gitfolder.tests.\(UUID().uuidString)")
        defer { try? service.delete() }

        try service.save("first-token")
        XCTAssertEqual(try service.load(), "first-token")

        try service.save("second-token")
        XCTAssertEqual(try service.load(), "second-token")

        try service.delete()
        XCTAssertNil(try service.load())
    }

    private func temporaryDirectory() throws -> URL {
        let url = FileManager.default.temporaryDirectory
            .appending(path: "GitFolderTests-\(UUID().uuidString)", directoryHint: .isDirectory)
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }

    @discardableResult
    private func runGit(_ arguments: [String], in workingDirectory: URL) throws -> GitFolder.GitCommandResult {
        let result = try GitRunner().run(arguments, in: workingDirectory, timeoutSeconds: 60)
        XCTAssertEqual(result.exitCode, 0, result.standardError)
        return result
    }
}

private final class FakeGitRunner: GitRunning, @unchecked Sendable {
    struct Call: Equatable {
        var arguments: [String]
        var environment: [String: String]
    }

    private(set) var calls: [Call] = []

    func run(
        _ arguments: [String],
        in workingDirectory: URL,
        timeoutSeconds: TimeInterval,
        environment: [String: String]
    ) throws -> GitFolder.GitCommandResult {
        calls.append(Call(arguments: arguments, environment: environment))
        return GitFolder.GitCommandResult(exitCode: 0, standardOutput: "", standardError: "")
    }
}
