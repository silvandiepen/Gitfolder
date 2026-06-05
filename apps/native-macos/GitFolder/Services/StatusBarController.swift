import AppKit
import SwiftUI

final class StatusBarController: NSObject {
    private let statusItem: NSStatusItem
    private let appModel: AppModel

    init(appModel: AppModel) {
        self.appModel = appModel
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        super.init()
        statusItem.button?.title = "GitFolder"
        rebuildMenu()
    }

    private func rebuildMenu() {
        let menu = NSMenu()
        menu.addItem(NSMenuItem(title: "Sync Now", action: #selector(syncNow), keyEquivalent: "s"))
        menu.addItem(NSMenuItem(title: appModel.config.app.pauseAllSyncing ? "Resume Syncing" : "Pause Syncing", action: #selector(togglePause), keyEquivalent: "p"))
        menu.addItem(NSMenuItem.separator())
        menu.addItem(NSMenuItem(title: "Folders (\(appModel.config.folders.count))", action: nil, keyEquivalent: ""))
        menu.addItem(NSMenuItem(title: "Add Folder…", action: #selector(addFolder), keyEquivalent: "a"))
        menu.addItem(NSMenuItem.separator())
        menu.addItem(NSMenuItem(title: "Settings…", action: #selector(openSettings), keyEquivalent: ","))
        menu.addItem(NSMenuItem(title: appModel.lastMessage, action: nil, keyEquivalent: ""))
        menu.addItem(NSMenuItem.separator())
        menu.addItem(NSMenuItem(title: "Quit GitFolder", action: #selector(quit), keyEquivalent: "q"))

        for item in menu.items where item.action != nil {
            item.target = self
        }
        statusItem.menu = menu
    }

    @objc private func syncNow() {
        appModel.syncNow()
        rebuildMenu()
    }

    @objc private func togglePause() {
        appModel.pauseAllSyncing()
        rebuildMenu()
    }

    @objc private func addFolder() {
        let service = FolderAccessService()
        guard let url = service.pickFolder() else { return }
        do {
            let bookmark = try service.bookmarkData(for: url)
            let folder = SyncedFolder.create(name: url.lastPathComponent, localPath: url.path, bookmarkData: bookmark, repoUrl: "")
            appModel.config.folders.append(folder)
            appModel.save()
        } catch {
            appModel.lastMessage = "Folder access failed: \(error.localizedDescription)"
        }
        rebuildMenu()
    }

    @objc private func openSettings() {
        NSApp.sendAction(Selector(("showSettingsWindow:")), to: nil, from: nil)
    }

    @objc private func quit() {
        NSApp.terminate(nil)
    }
}
