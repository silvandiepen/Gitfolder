import Foundation
import GitKit
import GitPontCore
import GitPontGitHub
import GitPontGitLab
import Observation

/// The top-level model for GitFolder iOS. Provider-agnostic: connects to GitHub,
/// GitLab.com, or a self-hosted GitLab with a personal access token (via git-pont),
/// then browses and edits a repository's files over the provider API — no local clone.
@MainActor
@Observable
final class AppModel {
    // MARK: Connection
    var connection: ProviderConnection?
    var isConnecting = false
    var isRestoring = true

    // MARK: Repos
    var repos: [GitRepository] = []
    var isLoadingRepos = false

    // MARK: Active repository
    var activeRepo: GitRepository?
    var isSaving = false

    // MARK: Status
    var errorMessage: String?

    var isConnected: Bool { connection != nil }

    @ObservationIgnored private var client: RepoFileClient?

    // MARK: Persistence
    @ObservationIgnored private let keychain = KeychainService(
        service: Bundle.main.bundleIdentifier ?? "app.hakobs.gitfolder"
    )
    @ObservationIgnored private let defaults = UserDefaults.standard
    @ObservationIgnored private let connectionKey = "gitfolder.connection"

    private struct StoredConnection: Codable {
        let choice: ProviderChoice
        let serverURL: String?
    }

    // MARK: - Lifecycle

    func restore() async {
        defer { isRestoring = false }
        guard let data = defaults.data(forKey: connectionKey),
              let stored = try? JSONDecoder().decode(StoredConnection.self, from: data),
              let token = ((try? keychain.load()) ?? nil)?.trimmingCharacters(in: .whitespacesAndNewlines),
              !token.isEmpty else { return }
        await connect(choice: stored.choice, serverURL: stored.serverURL, token: token, persist: false)
    }

    // MARK: - Connect

    /// Validate a token against the chosen provider, then load its repositories.
    func connect(choice: ProviderChoice, serverURL rawServerURL: String?, token rawToken: String, persist: Bool = true) async {
        let token = rawToken.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !token.isEmpty else { errorMessage = "Enter a personal access token."; return }

        isConnecting = true
        errorMessage = nil
        defer { isConnecting = false }

        let instance: GitProviderInstance
        let provider: any GitProvider
        switch choice {
        case .github:
            instance = .github
            provider = GitHubProvider(httpClient: URLSessionHTTPClient())
        case .gitlabCloud:
            instance = .gitLabCloud
            provider = GitLabProvider(httpClient: URLSessionHTTPClient(), instances: [.gitLabCloud])
        case .gitlabSelfHosted:
            guard let raw = rawServerURL?.trimmingCharacters(in: .whitespacesAndNewlines), !raw.isEmpty,
                  let url = URL(string: raw.hasPrefix("http") ? raw : "https://\(raw)") else {
                errorMessage = "Enter a valid GitLab server URL."
                return
            }
            instance = .gitLabSelfHosted(baseURL: url)
            provider = GitLabProvider(httpClient: URLSessionHTTPClient(), instances: [instance])
        }

        do {
            let account = try await provider.account(instance: instance, credential: GitCredential(accessToken: token))
            let connection = ProviderConnection(
                choice: choice, instance: instance, provider: provider, token: token, login: account.login
            )
            self.connection = connection
            if persist {
                try? keychain.save(token)
                let stored = StoredConnection(choice: choice, serverURL: rawServerURL)
                if let data = try? JSONEncoder().encode(stored) { defaults.set(data, forKey: connectionKey) }
            }
            await loadRepos()
        } catch {
            errorMessage = "Could not connect: \(error.localizedDescription)"
        }
    }

    func signOut() {
        try? keychain.delete()
        defaults.removeObject(forKey: connectionKey)
        connection = nil
        repos = []
        activeRepo = nil
        client = nil
    }

    // MARK: - Repos

    func loadRepos() async {
        guard let connection else { return }
        isLoadingRepos = true
        errorMessage = nil
        defer { isLoadingRepos = false }
        do {
            let list = try await connection.provider.repositories(context: connection.requestContext)
            repos = list.items.sorted { fullName($0).localizedCaseInsensitiveCompare(fullName($1)) == .orderedAscending }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func fullName(_ repo: GitRepository) -> String {
        "\(repo.reference.namespace)/\(repo.reference.name)"
    }

    // MARK: - Open / close a repository

    func openRepo(_ repo: GitRepository) {
        guard let connection else { return }
        activeRepo = repo
        errorMessage = nil
        client = RepoFileClient(connection: connection, repo: repo)
    }

    func closeRepo() {
        activeRepo = nil
        client = nil
    }

    // MARK: - Files

    func list(_ directory: String) async throws -> [RepoEntry] {
        guard let client else { return [] }
        return try await client.list(directory)
    }

    func readText(_ path: String) async throws -> String {
        guard let client else { throw GitPontError.invalidProviderResponse("No repository open.") }
        return try await client.readText(path)
    }

    /// Save a file's text as one commit. Returns true on success.
    @discardableResult
    func save(path: String, text: String, message: String) async -> Bool {
        guard let client else { return false }
        isSaving = true
        errorMessage = nil
        defer { isSaving = false }
        do {
            try await client.write(path: path, text: text, message: message)
            return true
        } catch {
            errorMessage = error.localizedDescription
            return false
        }
    }

    /// Create a new file. Returns true on success.
    @discardableResult
    func createFile(path: String, text: String) async -> Bool {
        await save(path: path, text: text, message: "Create \(path)")
    }

    /// Delete a file. Returns true on success.
    @discardableResult
    func delete(path: String) async -> Bool {
        guard let client else { return false }
        isSaving = true
        errorMessage = nil
        defer { isSaving = false }
        do {
            try await client.delete(path: path, message: "Delete \(path)")
            return true
        } catch {
            errorMessage = error.localizedDescription
            return false
        }
    }
}
