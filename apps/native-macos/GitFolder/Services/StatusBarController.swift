import AppKit
import SwiftUI

@MainActor
final class StatusBarController: NSObject {
    private let statusItem: NSStatusItem
    private let appModel: AppModel
    private var refreshTimer: Timer?

    init(appModel: AppModel) {
        self.appModel = appModel
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        super.init()
        statusItem.button?.title = "GitFolder"
        rebuildMenu()
        refreshTimer = Timer.scheduledTimer(withTimeInterval: 5, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.rebuildMenu()
            }
        }
    }

    func invalidate() {
        refreshTimer?.invalidate()
        refreshTimer = nil
    }

    func rebuildMenu() {
        let menu = NSMenu()

        let syncItem = NSMenuItem(title: appModel.isSyncing ? "Syncing…" : "Sync All Now", action: #selector(syncNow), keyEquivalent: "s")
        syncItem.isEnabled = !appModel.isSyncing && !appModel.config.folders.isEmpty
        menu.addItem(syncItem)

        menu.addItem(NSMenuItem(title: appModel.config.app.pauseAllSyncing ? "Resume Syncing" : "Pause Syncing", action: #selector(togglePause), keyEquivalent: "p"))
        menu.addItem(NSMenuItem.separator())

        if appModel.config.folders.isEmpty {
            let emptyItem = NSMenuItem(title: "No folders configured", action: nil, keyEquivalent: "")
            emptyItem.isEnabled = false
            menu.addItem(emptyItem)
        } else {
            for folder in appModel.config.folders {
                let item = NSMenuItem(title: menuTitle(for: folder), action: #selector(syncFolder(_:)), keyEquivalent: "")
                item.representedObject = folder.id.uuidString
                item.isEnabled = !appModel.isSyncing && folder.enabled && !folder.repoUrl.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                menu.addItem(item)
            }
        }

        menu.addItem(NSMenuItem(title: "Add Folder…", action: #selector(openSettings), keyEquivalent: "a"))
        menu.addItem(NSMenuItem.separator())
        menu.addItem(NSMenuItem(title: "Settings…", action: #selector(openSettings), keyEquivalent: ","))

        let statusItem = NSMenuItem(title: appModel.lastMessage, action: nil, keyEquivalent: "")
        statusItem.isEnabled = false
        menu.addItem(statusItem)
        menu.addItem(NSMenuItem.separator())
        menu.addItem(NSMenuItem(title: "Quit GitFolder", action: #selector(quit), keyEquivalent: "q"))

        for item in menu.items where item.action != nil {
            item.target = self
        }
        self.statusItem.menu = menu
    }

    @objc private func syncNow() {
        appModel.syncNow()
        rebuildMenu()
    }

    @objc private func syncFolder(_ sender: NSMenuItem) {
        guard let idString = sender.representedObject as? String, let id = UUID(uuidString: idString) else { return }
        appModel.syncNow(folderID: id)
        rebuildMenu()
    }

    @objc private func togglePause() {
        appModel.pauseAllSyncing()
        rebuildMenu()
    }

    @objc private func openSettings() {
        NSApp.sendAction(Selector(("showSettingsWindow:")), to: nil, from: nil)
    }

    @objc private func quit() {
        NSApp.terminate(nil)
    }

    private func menuTitle(for folder: SyncedFolder) -> String {
        let prefix: String
        switch folder.lastStatus {
        case .synced: prefix = "✓"
        case .syncing: prefix = "↻"
        case .error, .conflict: prefix = "!"
        case .paused: prefix = "Ⅱ"
        default: prefix = "•"
        }
        return "\(prefix) Sync \(folder.name)"
    }
}
