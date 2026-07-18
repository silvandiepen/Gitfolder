import Foundation
import GitKit
import GitPontCore
import GitPontGitHub

/// A `BoardFileSource` backed by a hosted git provider's REST API through git-pont —
/// the iOS transport. Unlike macOS (which shells out to `git` against a local clone),
/// iOS has no shell, so the board is read directly over the API: directory listings
/// and file contents for a given repo + branch.
///
/// It is provider-agnostic: pass any git-pont provider (`GitHubProvider`,
/// `GitLabProvider`, …) and its `GitProviderInstance` (including a self-hosted GitLab
/// base URL), so GitHub, GitLab cloud, and custom GitLab installs all load the same
/// way. Writes will use `commitFile`/`deleteFile` in a later step; this is the read
/// path the board loads through.
struct GitPontFileSource: BoardFileSource {
    private let provider: any GitProvider
    private let context: GitProviderRequestContext
    private let repository: GitRepositoryReference
    private let ref: String

    init(
        provider: any GitProvider,
        instance: GitProviderInstance,
        owner: String,
        repo: String,
        branch: String,
        token: String
    ) {
        self.provider = provider
        let now = Date()
        let connection = GitConnection(
            id: "gitkanban",
            instance: instance,
            accountID: "account",
            accountLogin: owner,
            authMethod: .personalAccessToken,
            createdAt: now,
            updatedAt: now
        )
        self.context = GitProviderRequestContext(
            connection: connection,
            credential: GitCredential(accessToken: token)
        )
        self.repository = GitRepositoryReference(
            instance: instance, namespace: owner, name: repo, defaultBranch: branch
        )
        self.ref = branch
    }

    /// Convenience for a github.com repo.
    static func gitHub(owner: String, repo: String, branch: String, token: String) -> GitPontFileSource {
        GitPontFileSource(
            provider: GitHubProvider(httpClient: URLSessionHTTPClient()),
            instance: .github,
            owner: owner, repo: repo, branch: branch, token: token
        )
    }

    func list(_ directory: String) async throws -> [BoardFileEntry] {
        let reference = GitFileReference(repository: repository, path: directory, ref: ref)
        let result = try await provider.listDirectory(reference, context: context)
        return result.items.map { entry in
            BoardFileEntry(
                name: entry.name,
                path: entry.path,
                kind: entry.type == .directory ? .directory : .file
            )
        }
    }

    func readText(_ path: String) async throws -> String {
        let reference = GitFileReference(repository: repository, path: path, ref: ref)
        let file = try await provider.readFile(reference, context: context)
        guard let text = String(data: file.content, encoding: .utf8) else {
            throw GitPontError.invalidProviderResponse("File is not UTF-8: \(path)")
        }
        return text
    }

    // MARK: Writes

    /// Create or overwrite a file with `text` in one commit (last-writer-wins).
    func write(path: String, text: String, message: String) async throws {
        let change = GitFileChange(
            reference: GitFileReference(repository: repository, path: path, ref: ref),
            content: Data(text.utf8),
            message: message,
            targetBranch: ref,
            allowBlindOverwrite: true
        )
        _ = try await provider.commitFile(change, context: context)
    }

    /// Delete a file in one commit. Fetches the current version first (providers that
    /// require the blob sha to delete), falling back to a blind delete.
    func delete(path: String, message: String) async throws {
        let reference = GitFileReference(repository: repository, path: path, ref: ref)
        let version = try? await provider.readFile(reference, context: context).version
        let request = GitFileDeleteRequest(
            reference: reference,
            message: message,
            targetBranch: ref,
            expectedVersion: version,
            allowBlindOverwrite: version == nil
        )
        _ = try await provider.deleteFile(request, context: context)
    }
}
