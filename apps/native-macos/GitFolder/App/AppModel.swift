import Foundation
import Observation

@Observable
final class AppModel {
    var config: GitFolderConfig = .empty
    var isSyncing = false
    var lastMessage = "Ready"

    private let configStore = ConfigStore()

    func load() {
        do {
            config = try configStore.load()
            lastMessage = "Ready"
        } catch {
            config = .empty
            lastMessage = "Config reset: \(error.localizedDescription)"
        }
    }

    func save() {
        do {
            try configStore.save(config)
            lastMessage = "Saved"
        } catch {
            lastMessage = "Could not save config: \(error.localizedDescription)"
        }
    }

    func pauseAllSyncing() {
        config.app.pauseAllSyncing.toggle()
        save()
    }

    func syncNow() {
        isSyncing = true
        lastMessage = "Sync engine not wired yet"
        isSyncing = false
    }
}
