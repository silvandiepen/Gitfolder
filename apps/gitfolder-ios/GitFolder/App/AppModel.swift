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

    // MARK: Repositories (added "folders" + the open one)
    /// Repositories the user has added — shown on the home screen like local folders.
    var addedRepos: [RepoRef] = []
    /// The currently open repository (nil = showing the home list). Persisted so the
    /// app reopens the same repo on next launch.
    var activeRepo: RepoRef?
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
    @ObservationIgnored private let addedReposKey = "gitfolder.addedRepos"
    @ObservationIgnored private let activeRepoKey = "gitfolder.activeRepo"

    private struct StoredConnection: Codable {
        let choice: ProviderChoice
        let serverURL: String?
    }

    // MARK: - Lifecycle

    func restore() async {
        defer { isRestoring = false }
        loadAddedRepos()
        guard let data = defaults.data(forKey: connectionKey),
              let stored = try? JSONDecoder().decode(StoredConnection.self, from: data),
              let token = ((try? keychain.load()) ?? nil)?.trimmingCharacters(in: .whitespacesAndNewlines),
              !token.isEmpty else { return }
        await connect(choice: stored.choice, serverURL: stored.serverURL, token: token, persist: false)
        // Reopen the last repository so closing and reopening the app lands in the
        // same place instead of the home list.
        if isConnected, let saved = defaults.string(forKey: activeRepoKey),
           let ref = addedRepos.first(where: { $0.fullName == saved }) {
            openRepo(ref)
        }
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

        await establish(choice: choice, instance: instance, provider: provider, token: token, serverURL: rawServerURL, persist: persist)
    }

    /// Validate a token/credential against a provider, set the active connection,
    /// persist it, and load repositories. Shared by token and OAuth connect paths.
    private func establish(
        choice: ProviderChoice, instance: GitProviderInstance, provider: any GitProvider,
        token: String, serverURL: String?, persist: Bool
    ) async {
        do {
            let account = try await provider.account(instance: instance, credential: GitCredential(accessToken: token))
            connection = ProviderConnection(
                choice: choice, instance: instance, provider: provider, token: token, login: account.login
            )
            if persist {
                try? keychain.save(token)
                let stored = StoredConnection(choice: choice, serverURL: serverURL)
                if let data = try? JSONEncoder().encode(stored) { defaults.set(data, forKey: connectionKey) }
            }
            await loadRepos()
        } catch {
            errorMessage = "Could not connect: \(error.localizedDescription)"
        }
    }

    // MARK: - GitHub OAuth (device flow)

    /// The active GitHub device-flow session (user code + verification URL) while the
    /// user authorises in a browser. Non-nil means the Connect screen shows the code.
    var deviceAuth: GitOAuthDeviceSession?

    @ObservationIgnored private let gitHubOAuthConfig = OAuthAppConfig(
        clientID: "Ov23li24tWFt7qLuLqCe", scopes: ["repo"]
    )

    /// Begin GitHub sign-in with the OAuth device flow: request a user code, surface it
    /// for the browser, then poll until the user authorises.
    func startGitHubOAuth() async {
        errorMessage = nil
        isConnecting = true
        let provider = GitHubProvider(httpClient: URLSessionHTTPClient(), oauth: gitHubOAuthConfig)
        do {
            let result = try await provider.startOAuth(GitOAuthStartRequest(
                instance: .github, method: .oauthDevice, appConfig: gitHubOAuthConfig))
            guard case let .device(session) = result else {
                errorMessage = "Unexpected OAuth response from GitHub."
                isConnecting = false
                return
            }
            deviceAuth = session
            await pollGitHubOAuth(provider: provider, session: session)
        } catch {
            errorMessage = "Could not start sign-in: \(error.localizedDescription)"
            isConnecting = false
        }
    }

    func cancelOAuth() {
        deviceAuth = nil
        isConnecting = false
    }

    private func pollGitHubOAuth(provider: GitHubProvider, session: GitOAuthDeviceSession) async {
        var interval = max(session.interval, 5)
        // Keep the code on screen and keep polling until the user authorises (success),
        // explicitly declines, the code expires, or the user cancels. Transient errors
        // (network blips, still-pending) never tear the screen down.
        while Date() < session.expiresAt {
            try? await Task.sleep(nanoseconds: UInt64(interval * 1_000_000_000))
            if deviceAuth == nil { return } // cancelled by the user
            do {
                let credential = try await provider.completeOAuth(GitOAuthCompletionRequest(
                    instance: .github, method: .oauthDevice, appConfig: gitHubOAuthConfig,
                    deviceCode: session.deviceCode))
                deviceAuth = nil
                await establish(choice: .github, instance: .github, provider: provider,
                                token: credential.accessToken, serverURL: nil, persist: true)
                isConnecting = false
                return
            } catch GitPontError.authenticationFailed(let message) {
                let m = message.lowercased()
                if m.contains("slow") { interval += 5 }                 // back off, keep polling
                if m.contains("denied") || m.contains("declined") {     // user said no
                    finishOAuth(error: "Sign-in was declined on GitHub.")
                    return
                }
                if m.contains("expired") {                              // code no longer valid
                    finishOAuth(error: "The code expired. Please try again.")
                    return
                }
                // "authorization_pending" and anything else: keep waiting.
                continue
            } catch {
                // Transient (e.g. network) — do not close the screen; poll again.
                continue
            }
        }
        finishOAuth(error: "Sign-in timed out. Please try again.")
    }

    private func finishOAuth(error: String) {
        guard deviceAuth != nil else { return } // already resolved/cancelled
        deviceAuth = nil
        isConnecting = false
        errorMessage = error
    }

    func signOut() {
        try? keychain.delete()
        defaults.removeObject(forKey: connectionKey)
        defaults.removeObject(forKey: addedReposKey)
        defaults.removeObject(forKey: activeRepoKey)
        connection = nil
        repos = []
        addedRepos = []
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

    /// Add a repository to the home list (like adding a folder) and open it.
    func addRepo(_ repo: GitRepository) {
        let ref = RepoRef(
            namespace: repo.reference.namespace,
            name: repo.reference.name,
            branch: repo.reference.defaultBranch ?? "main",
            isPrivate: repo.isPrivate
        )
        if !addedRepos.contains(where: { $0.id == ref.id }) {
            addedRepos.append(ref)
            addedRepos.sort { $0.fullName.localizedCaseInsensitiveCompare($1.fullName) == .orderedAscending }
            persistAddedRepos()
        }
        openRepo(ref)
    }

    /// Remove a repo from the home list. If it's open, return to the home list.
    func removeAddedRepo(_ ref: RepoRef) {
        addedRepos.removeAll { $0.id == ref.id }
        persistAddedRepos()
        if activeRepo?.id == ref.id { closeRepo() }
    }

    func openRepo(_ ref: RepoRef) {
        guard let connection else { return }
        activeRepo = ref
        errorMessage = nil
        client = RepoFileClient(connection: connection, ref: ref)
        defaults.set(ref.fullName, forKey: activeRepoKey)
    }

    func closeRepo() {
        activeRepo = nil
        client = nil
        defaults.removeObject(forKey: activeRepoKey)
    }

    private func persistAddedRepos() {
        if let data = try? JSONEncoder().encode(addedRepos) {
            defaults.set(data, forKey: addedReposKey)
        }
    }

    private func loadAddedRepos() {
        guard let data = defaults.data(forKey: addedReposKey),
              let saved = try? JSONDecoder().decode([RepoRef].self, from: data) else { return }
        addedRepos = saved
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

    func readData(_ path: String) async throws -> Data {
        guard let client else { throw GitPontError.invalidProviderResponse("No repository open.") }
        return try await client.readData(path)
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

    /// Write raw bytes to a path as one commit (used by Duplicate). Returns true on success.
    @discardableResult
    func writeData(path: String, data: Data, message: String) async -> Bool {
        guard let client else { return false }
        isSaving = true
        errorMessage = nil
        defer { isSaving = false }
        do {
            try await client.writeData(path: path, data: data, message: message)
            return true
        } catch {
            errorMessage = error.localizedDescription
            return false
        }
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

    // MARK: - Folder operations
    //
    // A git host has no first-class folders — they are implied by file paths. So
    // moving/renaming/deleting a folder means rewriting every file under it (one commit
    // each). Fine for typical folders; large trees take a moment.

    /// Every file path under `path` (recursive).
    func listAllFiles(under path: String) async -> [String] {
        guard let client else { return [] }
        var result: [String] = []
        var stack = [path]
        while let dir = stack.popLast() {
            guard let entries = try? await client.list(dir) else { continue }
            for entry in entries {
                if entry.isDirectory { stack.append(entry.path) } else { result.append(entry.path) }
            }
        }
        return result
    }

    /// Move (or rename) a folder to `newFolderPath` by moving each file under it. Every
    /// file is read, written to its new path, and the old one deleted.
    @discardableResult
    func moveFolder(from: String, to newFolderPath: String) async -> Bool {
        guard let client, from != newFolderPath, !newFolderPath.isEmpty else { return false }
        isSaving = true
        errorMessage = nil
        defer { isSaving = false }
        let files = await listAllFiles(under: from)
        guard !files.isEmpty else {
            errorMessage = "That folder has no files to move (git has no empty folders)."
            return false
        }
        let message = "Move \(from) to \(newFolderPath)"
        do {
            for file in files {
                let relative = String(file.dropFirst(from.count).drop { $0 == "/" })
                let dest = newFolderPath + "/" + relative
                let data = try await client.readData(file)
                try await client.writeData(path: dest, data: data, message: message)
                try await client.delete(path: file, message: message)
            }
            return true
        } catch {
            errorMessage = error.localizedDescription
            return false
        }
    }

    /// Delete a folder by deleting every file under it.
    @discardableResult
    func deleteFolder(_ path: String) async -> Bool {
        guard let client else { return false }
        isSaving = true
        errorMessage = nil
        defer { isSaving = false }
        let files = await listAllFiles(under: path)
        do {
            for file in files {
                try await client.delete(path: file, message: "Delete folder \(path)")
            }
            return true
        } catch {
            errorMessage = error.localizedDescription
            return false
        }
    }
}
