import Foundation
import GitPontCore

/// One entry in a repository directory listing.
struct RepoEntry: Identifiable, Hashable {
    let name: String
    let path: String
    let isDirectory: Bool
    var id: String { path }
}

/// A file view of a repository over a hosted git provider's REST API (via git-pont) —
/// the iOS transport. iOS has no `git` binary, so the app browses and edits files
/// directly through the API: list a directory, read a file, and write/delete files
/// (each write is one commit, pushed immediately).
struct RepoFileClient {
    let provider: any GitProvider
    let context: GitProviderRequestContext
    let repository: GitRepositoryReference
    let ref: String

    init(connection: ProviderConnection, repo: GitRepository) {
        self.provider = connection.provider
        self.context = connection.requestContext
        let branch = repo.reference.defaultBranch ?? "main"
        self.repository = GitRepositoryReference(
            instance: connection.instance,
            namespace: repo.reference.namespace,
            name: repo.reference.name,
            defaultBranch: branch
        )
        self.ref = branch
    }

    /// List a directory (empty string = repo root), folders first then files, A→Z.
    func list(_ directory: String) async throws -> [RepoEntry] {
        let reference = GitFileReference(repository: repository, path: directory, ref: ref)
        let result = try await provider.listDirectory(reference, context: context)
        return result.items
            .map { RepoEntry(name: $0.name, path: $0.path, isDirectory: $0.type == .directory) }
            .sorted { a, b in
                if a.isDirectory != b.isDirectory { return a.isDirectory && !b.isDirectory }
                return a.name.localizedCaseInsensitiveCompare(b.name) == .orderedAscending
            }
    }

    /// Read a UTF-8 file's text.
    func readText(_ path: String) async throws -> String {
        let reference = GitFileReference(repository: repository, path: path, ref: ref)
        let file = try await provider.readFile(reference, context: context)
        guard let text = String(data: file.content, encoding: .utf8) else {
            throw GitPontError.invalidProviderResponse("File is not UTF-8 text: \(path)")
        }
        return text
    }

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
