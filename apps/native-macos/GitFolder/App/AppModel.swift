import AppKit
import Foundation
import GitKit
import Observation

@MainActor
@Observable
final class AppModel {
    var config: GitFolderConfig = .empty
    var isSyncing = false
    var lastMessage = "Ready"
    var isShowingAddFolderSheet = false
    var focusedFolderID: UUID?
    var hasGitHubToken = false
    var gitHubLogin: String?

    @ObservationIgnored private let configStore: ConfigStore
    @ObservationIgnored private let syncEngine: GitSyncEngine
    @ObservationIgnored private let keychainService: KeychainService
    @ObservationIgnored private let gitHubOAuthService: GitHubOAuthService
    @ObservationIgnored private let loginItemService: LoginItemManaging
    @ObservationIgnored private let userDefaults: UserDefaults
    @ObservationIgnored private var scheduler: Timer?
    @ObservationIgnored private var didLoad = false
    @ObservationIgnored private let launchAtLoginPromptKey = "hasAskedLaunchAtLogin"

    init(
        configStore: ConfigStore = ConfigStore(),
        syncEngine: GitSyncEngine = GitSyncEngine(),
        keychainService: KeychainService = KeychainService(
            service: Bundle.main.bundleIdentifier ?? "app.hakobs.gitfolder"
        ),
        gitHubOAuthService: GitHubOAuthService = GitHubOAuthService(
            clientID: "Ov23li24tWFt7qLuLqCe",
            userAgent: "GitFolder"
        ),
        loginItemService: LoginItemManaging = LoginItemService(),
        userDefaults: UserDefaults = .standard
    ) {
        self.configStore = configStore
        self.syncEngine = syncEngine
        self.keychainService = keychainService
        self.gitHubOAuthService = gitHubOAuthService
        self.loginItemService = loginItemService
        self.userDefaults = userDefaults
    }

    func invalidateScheduler() {
        scheduler?.invalidate()
        scheduler = nil
    }

    func loadIfNeeded() {
        guard !didLoad else { return }
        didLoad = true
        load()
    }

    func load() {
        do {
            config = try configStore.load()
            syncLaunchAtLoginStateFromSystem()
            hasGitHubToken = (try? keychainService.load())?.nilIfEmpty != nil
            lastMessage = "Ready"
            startScheduler()
            refreshGitHubLogin()
        } catch {
            config = .empty
            syncLaunchAtLoginStateFromSystem()
            hasGitHubToken = (try? keychainService.load())?.nilIfEmpty != nil
            lastMessage = "Config reset: \(error.localizedDescription)"
            startScheduler()
            refreshGitHubLogin()
        }
    }

    func save(message: String = "Saved") {
        do {
            try configStore.save(config)
            lastMessage = message
        } catch {
            lastMessage = "Could not save config: \(error.localizedDescription)"
        }
    }

    func showAddFolderSheet() {
        isShowingAddFolderSheet = true
        focusedFolderID = nil
    }

    func focusFolder(id: UUID) {
        focusedFolderID = id
    }

    @discardableResult
    func addFolder(localURL: URL, repoUrl: String, authMode: AuthMode = .githubToken, branch: String, syncIntervalMinutes: Int) throws -> UUID {
        let service = FolderAccessService()
        let bookmark = try service.bookmarkData(for: localURL)
        let folder = SyncedFolder.create(
            name: localURL.lastPathComponent,
            localPath: localURL.path,
            bookmarkData: bookmark,
            repoUrl: repoUrl.trimmingCharacters(in: .whitespacesAndNewlines),
            authMode: authMode,
            branch: normalizedBranch(branch),
            syncIntervalMinutes: normalizedInterval(syncIntervalMinutes)
        )
        config.folders.append(folder)
        save(message: "Added \(folder.name)")
        return folder.id
    }

    func updateFolder(_ folder: SyncedFolder) {
        guard let index = config.folders.firstIndex(where: { $0.id == folder.id }) else { return }
        var copy = folder
        copy.repoUrl = copy.repoUrl.trimmingCharacters(in: .whitespacesAndNewlines)
        copy.branch = normalizedBranch(copy.branch)
        copy.syncIntervalMinutes = normalizedInterval(copy.syncIntervalMinutes)
        copy.updatedAt = Date()
        config.folders[index] = copy
        save(message: "Updated \(copy.name)")
    }

    func removeFolder(id: UUID) {
        guard let folder = config.folders.first(where: { $0.id == id }) else { return }
        config.folders.removeAll { $0.id == id }
        save(message: "Removed \(folder.name)")
    }

    func toggleFolder(id: UUID) {
        guard let index = config.folders.firstIndex(where: { $0.id == id }) else { return }
        config.folders[index].enabled.toggle()
        config.folders[index].lastStatus = config.folders[index].enabled ? .idle : .paused
        config.folders[index].updatedAt = Date()
        save(message: config.folders[index].enabled ? "Resumed \(config.folders[index].name)" : "Paused \(config.folders[index].name)")
    }

    func saveGitHubToken(_ token: String) {
        do {
            try keychainService.save(token)
            hasGitHubToken = token.trimmingCharacters(in: .whitespacesAndNewlines).nilIfEmpty != nil
            gitHubLogin = nil
            lastMessage = hasGitHubToken ? "GitHub token saved" : "GitHub token cleared"
            refreshGitHubLogin()
        } catch {
            lastMessage = "Could not save GitHub token: \(error.localizedDescription)"
        }
    }

    func clearGitHubToken() {
        do {
            try keychainService.delete()
            hasGitHubToken = false
            gitHubLogin = nil
            lastMessage = "GitHub token cleared"
        } catch {
            lastMessage = "Could not clear GitHub token: \(error.localizedDescription)"
        }
    }

    func requestGitHubConnectionCode() async throws -> GitHubDeviceAuthorization {
        let authorization = try await gitHubOAuthService.requestDeviceAuthorization()
        lastMessage = "Enter code \(authorization.userCode) on GitHub"
        return authorization
    }

    func finishGitHubConnection(_ authorization: GitHubDeviceAuthorization) async -> Bool {
        do {
            let token = try await gitHubOAuthService.waitForAccessToken(authorization: authorization)
            try keychainService.save(token)
            hasGitHubToken = true
            gitHubLogin = try? await gitHubOAuthService.loadViewerLogin(token: token)
            lastMessage = gitHubLogin.map { "GitHub connected as \($0)" } ?? "GitHub connected"
            return true
        } catch {
            lastMessage = "GitHub connection failed: \(error.localizedDescription)"
            return false
        }
    }

    func refreshGitHubLogin() {
        guard hasGitHubToken else {
            gitHubLogin = nil
            return
        }

        Task {
            do {
                guard let token = try keychainService.load()?.nilIfEmpty else { return }
                let login = try await gitHubOAuthService.loadViewerLogin(token: token)
                gitHubLogin = login
            } catch {
                gitHubLogin = nil
            }
        }
    }

    func testGitHubAccess(repoUrl: String, authMode: AuthMode = .githubToken, tokenOverride: String? = nil) async -> Bool {
        do {
            let token: String?
            if let override = tokenOverride?.trimmingCharacters(in: .whitespacesAndNewlines).nilIfEmpty {
                token = override
            } else {
                token = try keychainService.load()
            }
            try await syncEngine.testGitHubAccess(repoUrl: repoUrl, authMode: authMode, options: syncOptions(githubToken: token))
            lastMessage = "GitHub access verified"
            return true
        } catch {
            lastMessage = "GitHub access failed: \(error.localizedDescription)"
            return false
        }
    }

    func loadRemoteBranches(repoUrl: String, authMode: AuthMode = .githubToken) async -> [String] {
        do {
            let token = try keychainService.load()
            let branches = try await syncEngine.listRemoteBranches(repoUrl: repoUrl, authMode: authMode, options: syncOptions(githubToken: token))
            lastMessage = branches.isEmpty ? "No remote branches found" : "Loaded \(branches.count) branches"
            return branches
        } catch {
            lastMessage = "Could not load branches: \(error.localizedDescription)"
            return []
        }
    }

    func pauseAllSyncing() {
        config.app.pauseAllSyncing.toggle()
        save(message: config.app.pauseAllSyncing ? "Syncing paused" : "Syncing resumed")
    }

    func setLaunchAtLogin(_ enabled: Bool) {
        do {
            try loginItemService.setEnabled(enabled)
            config.app.launchAtLogin = loginItemService.isEnabled
            userDefaults.set(true, forKey: launchAtLoginPromptKey)
            save(message: config.app.launchAtLogin ? "GitFolder will open at login" : "GitFolder will not open at login")
        } catch {
            config.app.launchAtLogin = loginItemService.isEnabled
            lastMessage = "Could not update login item: \(error.localizedDescription)"
        }
    }

    func requestLaunchAtLoginIfNeeded() {
        guard !userDefaults.bool(forKey: launchAtLoginPromptKey), !loginItemService.isEnabled else {
            return
        }

        let alert = NSAlert()
        alert.messageText = "Open GitFolder when you log in?"
        alert.informativeText = "GitFolder can start automatically with macOS so folder syncing begins without opening it manually."
        alert.alertStyle = .informational
        alert.addButton(withTitle: "Open at Login")
        alert.addButton(withTitle: "Not Now")

        NSApp.activate(ignoringOtherApps: true)
        let response = alert.runModal()
        userDefaults.set(true, forKey: launchAtLoginPromptKey)

        if response == .alertFirstButtonReturn {
            setLaunchAtLogin(true)
        } else {
            config.app.launchAtLogin = false
            save(message: "Launch at login skipped")
        }
    }

    func chooseSSHPrivateKey() {
        let service = FolderAccessService()
        guard let url = service.pickPrivateKey() else { return }
        do {
            config.app.sshPrivateKeyBookmarkData = try service.bookmarkData(for: url)
            config.app.sshPrivateKeyPath = url.path
            save(message: "SSH key selected")
        } catch {
            lastMessage = "Could not save SSH key access: \(error.localizedDescription)"
        }
    }

    func clearSSHPrivateKey() {
        config.app.sshPrivateKeyBookmarkData = nil
        config.app.sshPrivateKeyPath = nil
        save(message: "SSH key cleared")
    }

    func syncNow(folderID: UUID? = nil) {
        guard !isSyncing else {
            lastMessage = "Sync already running"
            return
        }

        let folders: [SyncedFolder]
        if let folderID {
            folders = config.folders.filter { $0.id == folderID }
        } else {
            folders = config.folders
        }

        guard !folders.isEmpty else {
            lastMessage = "Add a folder first"
            return
        }

        isSyncing = true
        Task {
            await sync(folders: folders, manual: true)
        }
    }

    func syncDueFolders() {
        guard !config.app.pauseAllSyncing, !isSyncing else { return }
        let dueFolders = config.folders.filter { folder in
            guard folder.enabled else { return false }
            guard !folder.repoUrl.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return false }
            guard let lastSuccessfulSyncAt = folder.lastSuccessfulSyncAt else { return true }
            return Date().timeIntervalSince(lastSuccessfulSyncAt) >= TimeInterval(folder.syncIntervalMinutes * 60)
        }
        guard !dueFolders.isEmpty else { return }

        isSyncing = true
        Task {
            await sync(folders: dueFolders, manual: false)
        }
    }

    private func sync(folders: [SyncedFolder], manual: Bool) async {
        defer { isSyncing = false }

        if config.app.pauseAllSyncing && !manual {
            return
        }

        var successCount = 0
        var failureCount = 0
        var changedCount = 0

        for folder in folders {
            guard let index = config.folders.firstIndex(where: { $0.id == folder.id }) else { continue }
            guard config.folders[index].enabled else { continue }

            config.folders[index].lastStatus = .syncing
            config.folders[index].lastSyncAt = Date()
            config.folders[index].lastError = nil
            lastMessage = "Syncing \(config.folders[index].name)…"
            save(message: lastMessage)

            do {
                let outcome = try await syncEngine.sync(config.folders[index], options: syncOptions())
                apply(outcome.folder)
                successCount += 1
                if outcome.changed { changedCount += 1 }
                lastMessage = "\(outcome.folder.name): \(outcome.message)"
                save(message: lastMessage)
            } catch {
                failureCount += 1
                markFolderFailed(id: folder.id, error: error)
                save(message: lastMessage)
            }
        }

        if failureCount > 0 {
            lastMessage = "Synced \(successCount), failed \(failureCount)"
        } else if successCount == 0 {
            lastMessage = manual ? "No enabled folders to sync" : "No folders due"
        } else if changedCount == 0 {
            lastMessage = "All folders up to date"
        } else {
            lastMessage = "Synced \(changedCount) changed folder\(changedCount == 1 ? "" : "s")"
        }
        save(message: lastMessage)
    }

    private func apply(_ folder: SyncedFolder) {
        guard let index = config.folders.firstIndex(where: { $0.id == folder.id }) else { return }
        config.folders[index] = folder
    }

    private func markFolderFailed(id: UUID, error: Error) {
        guard let index = config.folders.firstIndex(where: { $0.id == id }) else { return }
        let userError: UserFacingError
        if let syncError = error as? GitSyncError {
            userError = syncError.userFacingError()
        } else {
            userError = UserFacingError(
                code: "sync_failed",
                title: "Sync failed",
                message: error.localizedDescription,
                recoverySuggestion: "Check folder permissions, Git configuration, and GitHub SSH access.",
                technicalDetailsLogId: nil
            )
        }

        config.folders[index].lastStatus = .error
        config.folders[index].lastError = userError
        config.folders[index].lastCheckedAt = Date()
        config.folders[index].updatedAt = Date()
        lastMessage = "\(config.folders[index].name): \(userError.message)"
    }

    private func startScheduler() {
        scheduler?.invalidate()
        scheduler = Timer.scheduledTimer(withTimeInterval: 60, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.syncDueFolders()
            }
        }
    }

    private func syncLaunchAtLoginStateFromSystem() {
        let isEnabled = loginItemService.isEnabled
        if config.app.launchAtLogin != isEnabled {
            config.app.launchAtLogin = isEnabled
            try? configStore.save(config)
        }
    }

    private func syncOptions(githubToken: String? = nil) -> GitSyncOptions {
        let token = githubToken ?? (try? keychainService.load())
        return GitSyncOptions(
            gitAuthorName: config.app.gitAuthorName,
            gitAuthorEmail: config.app.gitAuthorEmail,
            githubToken: token,
            sshPrivateKeyPath: config.app.sshPrivateKeyPath,
            sshPrivateKeyBookmarkData: config.app.sshPrivateKeyBookmarkData
        )
    }

    private func normalizedBranch(_ branch: String) -> String {
        let trimmed = branch.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? config.app.defaultBranch : trimmed
    }

    private func normalizedInterval(_ value: Int) -> Int {
        let allowed = [5, 15, 30, 60]
        return allowed.contains(value) ? value : config.app.defaultSyncIntervalMinutes
    }
}

private extension String {
    var nilIfEmpty: String? {
        isEmpty ? nil : self
    }
}
