import Foundation
import Observation

@MainActor
@Observable
final class AppModel {
    var config: GitFolderConfig = .empty
    var isSyncing = false
    var lastMessage = "Ready"

    @ObservationIgnored private let configStore: ConfigStore
    @ObservationIgnored private let syncEngine: GitSyncEngine
    @ObservationIgnored private var scheduler: Timer?

    init(configStore: ConfigStore = ConfigStore(), syncEngine: GitSyncEngine = GitSyncEngine()) {
        self.configStore = configStore
        self.syncEngine = syncEngine
    }

    func invalidateScheduler() {
        scheduler?.invalidate()
        scheduler = nil
    }

    func load() {
        do {
            config = try configStore.load()
            lastMessage = "Ready"
            startScheduler()
        } catch {
            config = .empty
            lastMessage = "Config reset: \(error.localizedDescription)"
            startScheduler()
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

    @discardableResult
    func addFolder(localURL: URL, repoUrl: String, branch: String, syncIntervalMinutes: Int) throws -> UUID {
        let service = FolderAccessService()
        let bookmark = try service.bookmarkData(for: localURL)
        let folder = SyncedFolder.create(
            name: localURL.lastPathComponent,
            localPath: localURL.path,
            bookmarkData: bookmark,
            repoUrl: repoUrl.trimmingCharacters(in: .whitespacesAndNewlines),
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

    func pauseAllSyncing() {
        config.app.pauseAllSyncing.toggle()
        save(message: config.app.pauseAllSyncing ? "Syncing paused" : "Syncing resumed")
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

    private func syncOptions() -> GitSyncOptions {
        GitSyncOptions(
            gitAuthorName: config.app.gitAuthorName,
            gitAuthorEmail: config.app.gitAuthorEmail,
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
