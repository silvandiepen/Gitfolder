import AppKit
import SwiftUI

struct MenuBarView: View {
    @Environment(AppModel.self) private var appModel
    @Environment(\.openSettings) private var openSettings

    var body: some View {
        VStack {
            header
            Divider()

            Button(appModel.isSyncing ? "Syncing…" : "Sync All Now", systemImage: "arrow.triangle.2.circlepath") {
                appModel.syncNow()
            }
            .keyboardShortcut("s")
            .disabled(appModel.isSyncing || appModel.config.folders.isEmpty)

            Button(appModel.config.app.pauseAllSyncing ? "Resume Syncing" : "Pause Syncing", systemImage: appModel.config.app.pauseAllSyncing ? "play.fill" : "pause.fill") {
                appModel.pauseAllSyncing()
            }
            .keyboardShortcut("p")

            Divider()

            if appModel.config.folders.isEmpty {
                Label("No folders configured", systemImage: "folder.badge.plus")
                    .foregroundStyle(.secondary)
            } else {
                ForEach(appModel.config.folders) { folder in
                    FolderMenu(folder: folder)
                }
            }

            Divider()

            Button("Add Folder…", systemImage: "folder.badge.plus") {
                appModel.showAddFolderSheet()
                openSettings()
            }
            .keyboardShortcut("a")

            SettingsLink {
                Label("Settings…", systemImage: "gearshape")
            }
            .keyboardShortcut(",")

            if !appModel.lastMessage.isEmpty {
                Text(appModel.lastMessage)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Divider()

            Button("Quit GitFolder", systemImage: "power") {
                NSApp.terminate(nil)
            }
            .keyboardShortcut("q")
        }
        .onAppear {
            appModel.loadIfNeeded()
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 8) {
                Image("MenuBarIcon")
                    .resizable()
                    .renderingMode(.template)
                    .frame(width: 16, height: 16)
                Text("GitFolder")
                    .font(.headline)
            }
            Text(summaryText)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    private var summaryText: String {
        if appModel.config.folders.isEmpty { return "No folders yet" }
        let errorCount = appModel.config.folders.filter { $0.lastStatus == .error || $0.lastStatus == .conflict }.count
        if errorCount > 0 { return "\(errorCount) folder\(errorCount == 1 ? "" : "s") need attention" }
        let syncedCount = appModel.config.folders.filter { $0.lastStatus == .synced }.count
        return "\(syncedCount)/\(appModel.config.folders.count) folders synced"
    }

}

private struct FolderMenu: View {
    @Environment(AppModel.self) private var appModel
    @Environment(\.openSettings) private var openSettings
    let folder: SyncedFolder

    var body: some View {
        Menu {
            Label(statusDescription, systemImage: statusIcon)
                .foregroundStyle(statusColor)

            if let lastSuccessfulSyncAt = folder.lastSuccessfulSyncAt {
                Text("Last synced: \(lastSuccessfulSyncAt.formatted(date: .abbreviated, time: .shortened))")
            }

            Divider()

            Button("Sync Now", systemImage: "arrow.triangle.2.circlepath") {
                appModel.syncNow(folderID: folder.id)
            }
            .disabled(appModel.isSyncing || !folder.enabled || folder.repoUrl.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)

            Button("Open Folder", systemImage: "folder") {
                NSWorkspace.shared.open(URL(fileURLWithPath: folder.localPath))
            }

            Button("Reveal in Finder", systemImage: "arrow.up.forward.app") {
                NSWorkspace.shared.activateFileViewerSelecting([URL(fileURLWithPath: folder.localPath)])
            }

            Button("Copy Repository URL", systemImage: "doc.on.doc") {
                NSPasteboard.general.clearContents()
                NSPasteboard.general.setString(folder.repoUrl, forType: .string)
                appModel.lastMessage = "Copied \(folder.name) repository URL"
            }
            .disabled(folder.repoUrl.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)

            Divider()

            Button(folder.enabled ? "Pause Folder" : "Resume Folder", systemImage: folder.enabled ? "pause.fill" : "play.fill") {
                appModel.toggleFolder(id: folder.id)
            }

            Button("Edit Settings…", systemImage: "slider.horizontal.3") {
                appModel.focusFolder(id: folder.id)
                NSApp.activate(ignoringOtherApps: true)
                openSettings()
            }
        } label: {
            Label {
                VStack(alignment: .leading, spacing: 2) {
                    Text(folder.name)
                    Text(statusDescription)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            } icon: {
                Image(systemName: statusIcon)
                    .foregroundStyle(statusColor)
            }
        }
    }

    private var statusDescription: String {
        switch folder.lastStatus {
        case .idle:
            return folder.enabled ? "Ready" : "Paused"
        case .checking:
            return "Checking"
        case .syncing:
            return "Syncing"
        case .synced:
            return "Synced"
        case .paused:
            return "Paused"
        case .waitingForConnection:
            return "Waiting for connection"
        case .needsAttention:
            return "Needs attention"
        case .error:
            return folder.lastError?.title ?? "Error"
        case .conflict:
            return "Conflict"
        }
    }

    private var statusIcon: String {
        switch folder.lastStatus {
        case .synced: return "checkmark.circle.fill"
        case .syncing, .checking: return "arrow.triangle.2.circlepath.circle.fill"
        case .paused: return "pause.circle.fill"
        case .error, .conflict: return "exclamationmark.triangle.fill"
        case .waitingForConnection, .needsAttention: return "exclamationmark.circle.fill"
        case .idle: return folder.enabled ? "circle" : "pause.circle.fill"
        }
    }

    private var statusColor: Color {
        switch folder.lastStatus {
        case .synced: return .green
        case .syncing, .checking: return .blue
        case .paused, .idle: return .secondary
        case .waitingForConnection, .needsAttention: return .orange
        case .error, .conflict: return .red
        }
    }
}
